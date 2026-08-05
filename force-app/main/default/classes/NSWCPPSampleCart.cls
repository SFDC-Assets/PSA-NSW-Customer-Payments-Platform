/**
 * @description Sample implementation of a cart/ordering flow using the NSW CPP payment platform.
 *              Implements the Callable interface so it can be invoked from OmniStudio, Integration
 *              Procedures or other Callable consumers without a direct Apex dependency.
 *              Demonstrates how to combine NSWCPPOperationInitiate, NSWCPPCalloutRequestPayment,
 *              and NSWCPPOperationPend into a single end-to-end order and payment request flow.
 * 
 *              Must be without sharing as the Guest User will perform some privilege actions as
 *              a result, so review this code thoroughly and be very careful with any alteration:
 *              - create NSW CPP Operation record
 *              - create NSW CPP Operation Step records
 *              - Perform a callout which requires metadata access
 *              - The Guest User will also need access to named credentials to initiate the payment
 *
 *              Supported actions:
 *              - 'order': validates units and service type, initiates a payment record, requests
 *                         a payment from the NSW CPP gateway and pends the result.
 *              - 'close': closes a failed payment, paymentReference is sent via HTTP redirect by
 *                         the NSW CPP gateway
 *
 * @author E. Schweitzer
 * @see NSWCPPClientUtilsGetUUID
 * @see NSWCPPOperationInitiate
 * @see NSWCPPCalloutRequestPayment
 * @see NSWCPPOperationPend
 * @see NSWCPPOperationClose
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global without sharing class NSWCPPSampleCart implements Callable {

    /** @description Unit prices per service type used to calculate order totals. */
    private static final Map<String, Decimal> SERVICES_UNIT_PRICE = new Map<String, Decimal> {
      'Individual' => 45.0,
      'Venue' => 750.0
    };

    /**
     * @description Entry point for the Callable interface. Dispatches to the appropriate
     *              action handler based on the action parameter.
     *
     *              Expected args keys:
     *              - input  (Map<String, Object>): action-specific input parameters.
     *              - output (Map<String, Object>): populated with results or error details.
     *              - options (Map<String, Object>): reserved for future use.
     *
     *              Supported actions:
     *              - 'order': requires input keys units (Integer), service (String),
     *                customerReference (String). Delegates to order(output, units, service,
     *                customerReference). Results are written to the output map.
     *              - 'close': closes a failed payment, requires input key paymentReference (String)
     *                that is sent via HTTP redirect by the NSW CPP gateway
     *
     * @param action The action to execute.
     * @param args   Map containing 'input', 'output', and 'options' sub-maps.
     * @return true on success, false on error (error details written to output).
     */
    global Object call(String action, Map<String, Object> args) {
        Map<String, Object> input = (Map<String, Object>) args.get('input');
        Map<String, Object> output = (Map<String, Object>) args.get('output');
        Map<String, Object> options = (Map<String, Object>) args.get('options');

        switch on action {
            when 'order' {
                Integer units = Integer.valueOf(input.get('units'));
                String service = String.valueOf(input.get('service'));
                String customerReference = String.valueOf(input.get('customerReference'));

                return this.order(output, units, service, customerReference);
            }
            when 'closePayment' {
                if (input.isEmpty()) {
                    setError(output, 'ARGLIST-002');
                    return false;
                }

                NSWCPPOperationClose.Request rq = new NSWCPPOperationClose.Request();
                rq.paymentReference = String.valueOf(input.get('paymentReference'));

                NSWCPPOperationClose.closePayment(rq);

                output.put('result', true);
                return true;
            }
            when else {
                return setError(output, 'ACTION-001');
            }
        }
    }

    /**
     * @description Writes a standardised error structure to the output map and returns false.
     *              Error codes:
     *              - ACTION-001: the requested action is not supported by this Callable.
     *              - ARGLIST-002: required input arguments were not supplied.
     *              - ORDER-SERVICE-001: the service type is not in SERVICES_UNIT_PRICE.
     *              - ORDER-UNIT-001: units is outside the allowed range (1-3).
     *              - ORDER-INIT-001: NSWCPPOperationInitiate returned no record Id.
     *              - ORDER-INIT-002: NSWCPPOperationPend returned no record Id.
     *
     * @param output    The output map to populate with error details.
     * @param errorCode A short error code string identifying the failure reason.
     * @return false, allowing callers to return the result directly.
     */
    public Boolean setError(Map<String, Object> output, String errorCode) {
        output.put('error', 'KO');
        output.put('errorCode', errorCode);
        return false;
    }

    /**
     * @description Validates the order, performs the NSW CPP callout to obtain a payment reference,
     *              then persists an initiated payment record and pends it in a single transaction.
     *
     *              The callout is intentionally performed before any DML so that no partial database
     *              state is created if the gateway rejects the request.
     *
     *              Execution sequence:
     *              1. Validate service type against SERVICES_UNIT_PRICE.
     *              2. Validate units is in the range 1-3.
     *              3. Call NSWCPPCalloutRequestPayment to obtain a paymentReference and payment URL.
     *              4. Call NSWCPPOperationInitiate to persist the NSWCPPPayment__c record.
     *              5. Call NSWCPPOperationPend to update the record status and persist a step.
     *
     *              On success the output map is populated with:
     *              - paymentReference (String): the gateway-issued payment reference.
     *              - nswCppPaymentURL (String): the URL to redirect the customer to for payment.
     *
     *              On any failure the output map is populated with error and errorCode keys
     *              via setError and the method returns false immediately.
     *
     * @param output            The Callable output map to populate with payment details or error info.
     * @param units             Number of service units being ordered (1-3 inclusive).
     * @param service           Service type label (must be a key in SERVICES_UNIT_PRICE).
     * @param customerReference Agency-provided customer reference number passed to the gateway.
     * @return true when the payment was successfully requested, initiated, and pended; false otherwise.
     */
    public Boolean order(
        Map<String, Object> output,
        Integer units,
        String service,
        String customerReference
    ) {
        Decimal pricePerUnit = SERVICES_UNIT_PRICE.get(service);

        if (pricePerUnit == null) {
            return setError(output, 'ORDER-SERVICE-001');
        }

        if (units < 1 || units > 3) {
            return setError(output, 'ORDER-UNIT-001');
        }

        Decimal total = units * pricePerUnit;
        String productDescription = units.toString() + 'x ' + service;
        String uuid = NSWCPPClientUtilsGetUUID.getUUID();

        /* request a payment to NSW CPP, this will return a payment reference */

        NSWCPPCalloutRequestPayment.Request rprq = new NSWCPPCalloutRequestPayment.Request();
        rprq.productDescription = productDescription;
        rprq.amount = total;
        rprq.customerReference = customerReference;
        rprq.agencyTransactionId = uuid;

        Map<String, Object> rprsMap = NSWCPPCalloutRequestPayment.requestPayment(rprq);
        String paymentReference = String.valueOf(rprsMap.get('paymentReference'));
        Boolean duplicate = Boolean.valueOf(rprsMap.get('duplicate'));
        String nswCppPaymentURL = String.valueOf(rprsMap.get('nswCppPaymentURL'));

        /* we hold off initiating the request on the DB until the callout has been performed */

        NSWCPPOperationInitiate.Request irq = new NSWCPPOperationInitiate.Request();
        irq.agencyTransactionId = uuid;
        irq.amount = total;
        irq.productDescription = productDescription;
        irq.customerReference = customerReference;

        Id tId = NSWCPPOperationInitiate.initiatePayment(irq);

        if (tId == null) {
            // Haven't been able to initiate
            return setError(output, 'ORDER-INIT-001');
        }

        Id pId = NSWCPPOperationPend.pendPayment(tId, paymentReference, duplicate);

        if (pId == null) {
            // Haven't been able to pend
            return setError(output, 'ORDER-INIT-002');
        }

        output.put('paymentReference', paymentReference);
        output.put('nswCppPaymentURL', nswCppPaymentURL);
        return true;
    }

    /**
     * @description Request wrapper for the invocable order method. Defines the input parameters
     *              required to process an order through the NSW CPP payment platform.
     */
    public class OrderRequest {
        @InvocableVariable(label='Quantity' required=true)
        public Integer quantity;
        @InvocableVariable(label='Service' required=true)
        public String service;
        @InvocableVariable(label='Customer Reference' required=false)
        public String customerReference;
    }

    /**
     * @description Response wrapper for the invocable order method. Contains the payment reference,
     *              payment URL, and error code returned from the NSW CPP payment platform.
     */
    public class OrderResponse {
        @InvocableVariable(label='Error Code')
        public String errorCode;
        @InvocableVariable(label='Payment Reference')
        public String paymentReference;
        @InvocableVariable(label='Payment URL')
        public String nswCppPaymentURL;

        /**
         * @description Default constructor. Initializes an empty OrderResponse.
         */
        public OrderResponse() {
            this.errorCode = null;
        }
        
        /**
         * @description Constructor that initializes the response with an error code.
         * @param errorCode The error code to set for this response.
         */
        public OrderResponse(String errorCode) {
            this.errorCode = errorCode;
        }
    }
 
    /**
     * @description Invocable method for processing orders through the NSW CPP payment platform.
     *              Validates order details, requests payment, and initiates the payment process.
     *              Supports bulk processing of multiple orders in a single invocation.
     *
     *              Error codes returned in OrderResponse.errorCode:
     *              - ORDER-SERVICE-001: invalid service type
     *              - ORDER-UNIT-001: quantity outside allowed range (1-3)
     *              - ORDER-INIT-001: failed to initiate payment record
     *              - ORDER-INIT-002: failed to pend payment record
     *              - ORDER-EXCEPTION: unexpected exception during processing
     *
     * @param orders List of OrderRequest objects containing order details to process.
     * @return List of OrderResponse objects with payment references, URLs, and error codes.
     */
    @InvocableMethod(
        category='NSW CPP' 
        label='Sample Cart Order' 
        description='Order goods'
    )
    public static List<OrderResponse> order(List<OrderRequest> orders) {
        List<OrderResponse> responses = new List<OrderResponse>();
        
        for (OrderRequest orderReq : orders) {
            OrderResponse response = processOrder(orderReq);
            responses.add(response);
        }
        
        return responses;
    }

    /**
     * @description Processes a single order request, validating inputs and orchestrating the payment flow.
     *
     * @param orderReq The order request to process.
     * @return OrderResponse containing payment details or error code.
     */
    private static OrderResponse processOrder(OrderRequest orderReq) {
        OrderResponse response = new OrderResponse();
        
        Integer quantity = orderReq.quantity;
        String service = orderReq.service;
        String customerReference = orderReq.customerReference;

        // Validate service type
        Decimal pricePerUnit = SERVICES_UNIT_PRICE.get(service);
        if (pricePerUnit == null) {
            response.errorCode = 'ORDER-SERVICE-001';
            return response;
        }

        // Validate quantity range
        if (quantity < 1 || quantity > 3) {
            response.errorCode = 'ORDER-UNIT-001';
            return response;
        }

        // Calculate order details
        Decimal total = quantity * pricePerUnit;
        String productDescription = quantity.toString() + 'x ' + service;
        String uuid = NSWCPPClientUtilsGetUUID.getUUID();

        try {
            // Request payment from NSW CPP gateway
            Map<String, Object> paymentResult = requestPaymentFromGateway(
                productDescription, total, customerReference, uuid
            );
            
            // Initiate and pend payment in Salesforce
            return initiateAndPendPayment(
                uuid, total, productDescription, customerReference, paymentResult, response
            );
        } catch (Exception e) {
            response.errorCode = 'ORDER-EXCEPTION: ' + e.getMessage();
            return response;
        }
    }

    /**
     * @description Requests a payment from the NSW CPP gateway.
     *
     * @param productDescription Description of the product/service being purchased.
     * @param amount Total amount for the payment.
     * @param customerReference Customer reference number.
     * @param agencyTransactionId Unique transaction identifier.
     * @return Map containing paymentReference, duplicate flag, and nswCppPaymentURL.
     */
    private static Map<String, Object> requestPaymentFromGateway(
        String productDescription,
        Decimal amount,
        String customerReference,
        String agencyTransactionId
    ) {
        NSWCPPCalloutRequestPayment.Request rprq = new NSWCPPCalloutRequestPayment.Request();
        rprq.productDescription = productDescription;
        rprq.amount = amount;
        rprq.customerReference = customerReference;
        rprq.agencyTransactionId = agencyTransactionId;
        
        return NSWCPPCalloutRequestPayment.requestPayment(rprq);
    }

    /**
     * @description Initiates and pends a payment in Salesforce after successful gateway request.
     *
     * @param uuid Unique transaction identifier.
     * @param amount Total payment amount.
     * @param productDescription Description of the product/service.
     * @param customerReference Customer reference number.
     * @param paymentResult Map containing gateway response data.
     * @param response OrderResponse object to populate with results or errors.
     * @return Updated OrderResponse with payment details or error code.
     */
    private static OrderResponse initiateAndPendPayment(
        String uuid,
        Decimal amount,
        String productDescription,
        String customerReference,
        Map<String, Object> paymentResult,
        OrderResponse response
    ) {
        String paymentReference = String.valueOf(paymentResult.get('paymentReference'));
        Boolean duplicate = Boolean.valueOf(paymentResult.get('duplicate'));
        String nswCppPaymentURL = String.valueOf(paymentResult.get('nswCppPaymentURL'));

        // Create payment record in Salesforce
        NSWCPPOperationInitiate.Request irq = new NSWCPPOperationInitiate.Request();
        irq.agencyTransactionId = uuid;
        irq.amount = amount;
        irq.productDescription = productDescription;
        irq.customerReference = customerReference;

        Id tId = NSWCPPOperationInitiate.initiatePayment(irq);
        if (tId == null) {
            response.errorCode = 'ORDER-INIT-001';
            return response;
        }

        // Pend the payment
        Id pId = NSWCPPOperationPend.pendPayment(tId, paymentReference, duplicate);
        if (pId == null) {
            response.errorCode = 'ORDER-INIT-002';
            return response;
        }

        // Populate successful response
        response.paymentReference = paymentReference;
        response.nswCppPaymentURL = nswCppPaymentURL;
        return response;
    }
}