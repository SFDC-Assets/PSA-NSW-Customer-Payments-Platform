/**
 * @description Executes the NSW CPP request payment API call (POST /api/request-payment).
 *              Extends NSWCPPCallout to inherit named credential resolution, timeout/compression
 *              settings, and URL parameter merging.
 *
 *              On a successful (HTTP 200) response the gateway returns a paymentReference and the
 *              class derives the full nswCppPaymentURL by merging the paymentReference into the
 *              payment URL template resolved at construction time.
 *
 *              Exposes three entry points:
 *              - @InvocableMethod for Flow and OmniScript consumers via the typed Request class.
 *              - requestPayment(Request) static helper for direct Apex invocation with a typed request.
 *              - requestPayment(Map) static helper for loosely-typed map-based invocation.
 *
 * @author E. Schweitzer
 * @see NSWCPPCallout
 * @see NSWCPPOperationInitiate
 * @see NSWCPPOperationPend
 */
global class NSWCPPCalloutRequestPayment extends NSWCPPCallout {

    /** @description Relative URL for the request payment endpoint. No path parameters. */
    static final String HTTP_ENDPOINT = '/api/request-payment';

    /** @description HTTP verb used for the request payment endpoint. */
    static final String HTTP_VERB = 'POST';

    /**
     * @description Optional discount to apply to the payment request.
     *              Part of the Request body; include in the discounts list.
     */
    @JsonAccess(serializable='always')
    global class Discount {
        /** @description Discount amount to apply. */
        public Decimal amount;
        /** @description Discount code issued by the agency. */
        public String code;
        /** @description Agency reference associated with this discount. */
        public String reference;
    }

    /**
     * @description Disbursement instruction directing a portion of the payment to a specific agency.
     *              Part of the Request body; include in the disbursements list.
     */
    @JsonAccess(serializable='always')
    global class Disbursement {
        /** @description Amount to disburse to the specified agency. */
        public Decimal amount;
        /** @description Agency code identifying the recipient. */
        public String agencyCode;
    }

    /**
     * @description JSON-serialisable request body for the NSW CPP request payment API.
     *              callingSystem is injected automatically at callout time from the resolved
     *              NSWCPPCallingSystem__mdt record and must not be set by callers.
     *              Use the add(Disbursement) and add(Discount) fluent methods to attach
     *              optional line items before passing the request to requestPayment().
     */
    @JsonAccess(serializable='always')
    global class Request {
        /** @description Payment description shown to the customer. Mandatory. Maximum 250 characters. */
        @InvocableVariable(label='Product Description' required=true)
        public String productDescription;
        /** @description Payment amount. Mandatory. Must be between 0 and 1,000,000 with at most 2 decimal places. */
        @InvocableVariable(required=true label='Amount')
        public Decimal amount;
        /** @description Optional list of discounts to apply. */
        public List<Discount> discounts;
        /** @description Agency-provided customer reference. Optional. Maximum 250 characters. */
        @InvocableVariable(label='Customer Reference Number')
        public String customerReference;
        /** @description Unique agency transaction identifier. Mandatory. Maximum 50 characters. */
        @InvocableVariable(required=true label='Agency Transaction Id')
        public String agencyTransactionId;
        /** @description Sub-agency code. Optional. Deprecated — do not use for new integrations. */
        public String subAgencyCode { get; set; }
        /** @description Injected at callout time from the resolved calling system. Do not set manually. */
        public String callingSystem { get; set; }
        /** @description True to set up a recurring payment token with the gateway. Optional. */
        public Boolean setupRecurringPayment { get; set; }
        /** @description Optional list of disbursement instructions. */
        public List<Disbursement> disbursements;
        /** @description Optional map of arbitrary transaction reference key-value pairs. */
        public Map<String, Object> transactionReferences;

        /**
         * @description Fluent method to append a disbursement to the request.
         *              Initialises the disbursements list if it is null.
         * @param disbursement Disbursement to add.
         * @return This Request instance, for chaining.
         */
        public Request add(Disbursement disbursement) {
            if (this.disbursements == null) {
                this.disbursements = new List<Disbursement>();
            }

            this.disbursements.add(disbursement);
            return this;
        }

        /**
         * @description Fluent method to append a discount to the request.
         *              Initialises the discounts list if it is null.
         * @param discount Discount to add.
         * @return This Request instance, for chaining.
         */
        public Request add(Discount discount) {
            if (this.discounts == null) {
                this.discounts = new List<Discount>();
            }

            this.discounts.add(discount);
            return this;
        }
    }

    /**
     * @description Typed response from the NSW CPP request payment API.
     *              nswCppStatusCode is always populated with the HTTP status code.
     *              On success (HTTP 200), paymentReference, duplicate, and nswCppPaymentURL are populated.
     *              On failure only nswCppStatusCode is populated; callers should inspect it to
     *              determine the failure reason from the gateway.
     */
    @JsonAccess(serializable='always')
    global class Response {
        /** @description Gateway-issued payment reference for this transaction. Populated on success. */
        @InvocableVariable(label='NSW CPP Payment Reference Number')
        public String paymentReference;
        /** @description True if the gateway considers this a duplicate payment request. Populated on success. */
        @InvocableVariable(label='Duplicate request flag')
        public Boolean duplicate;
        /** @description Fully resolved URL to redirect the customer to for payment. Populated on success. */
        @InvocableVariable(label='NSW CPP Payment URL')
        public String nswCppPaymentURL;
        /** @description HTTP status code of the gateway response. Always populated. */
        @InvocableVariable(label='Status Code (always present)')
        public Integer nswCppStatusCode;

        /**
         * @description Default constructor. Initialises paymentReference to null.
         */
        Response() {
            this.paymentReference = null;
        }

        /**
         * @description Convenience constructor that populates the response from an untyped map
         *              returned by the callout(Request) instance method.
         * @param rsMap Untyped map containing paymentReference, duplicate, nswCppPaymentURL,
         *              and nswCppStatusCode keys.
         */
        Response(Map<String, Object> rsMap) {
            this.paymentReference = (String) rsMap.get('paymentReference');
            this.duplicate = (Boolean) rsMap.get('duplicate');
            this.nswCppPaymentURL = (String) rsMap.get('nswCppPaymentURL');
            this.nswCppStatusCode = (Integer) rsMap.get('nswCppStatusCode');
        }
    }

    /**
     * @description Constructs a new instance and initialises the inherited callout configuration
     *              by resolving the calling system for the current network context.
     * @throws NSWCPPCallout.NSWCPPNoCallingSystemException if no calling system is configured
     *                                                      for the current network.
     */
    public NSWCPPCalloutRequestPayment() {
        super();
    }

    /**
     * @description Invocable entry point for Flow and OmniScript consumers.
     *              Processes one payment request per Request element and returns a Response for each.
     * @param paymentRequests List of Request objects, each describing a payment to request.
     * @return A list of Response objects in the same order as the input list.
     */
    @InvocableMethod(
        category='NSW CPP'
        label='Request Payment'
        description='Requests a payment using the NSW CPP platform.'
    )
    public static List<Response> requestPayment(List<Request> paymentRequests) {
        NSWCPPCalloutRequestPayment rp = new NSWCPPCalloutRequestPayment();

        List<Response> responses = new List<Response>();
        for (Request rq : paymentRequests) {
            Map<String, Object> rsMap = requestPayment(rq);
            responses.add(new Response(rsMap));
        }

        return responses;
    }

    /**
     * @description Executes the request payment callout and returns the raw response as an untyped map.
     *              Injects the resolved callingSystem into the request before sending.
     *              On HTTP 200, constructs the full nswCppPaymentURL by merging the returned
     *              paymentReference into the payment URL template, then adds both nswCppPaymentURL
     *              and nswCppStatusCode to the map.
     *              On non-200 responses, returns a map containing only nswCppStatusCode.
     * @param rq Typed request body describing the payment.
     * @return Untyped map of the gateway response enriched with nswCppPaymentURL and nswCppStatusCode.
     */
    public Map<String, Object> callout(Request rq) {
        rq.callingSystem = this.callingSystem;
        HttpResponse rs = super.callout(HTTP_ENDPOINT, HTTP_VERB, rq);
        Integer rc = rs.getStatusCode();
        Map<String, Object> rv;

        if (rc == 200) {
            rv = (Map<String, Object>) JSON.deserializeUntyped(rs.getBody());
            String nswCppPaymentURL = this.mergeParams(this.paymentURL, new Map<String, String> {
                'paymentReference' => (String) rv.get('paymentReference')
            });

            rv.put('nswCppPaymentURL', nswCppPaymentURL);
            rv.put('nswCppStatusCode', rc);
        } else {
            rv = new Map<String, Object> { 'nswCppStatusCode' => rc };
        }

        return rv;
    }

    /**
     * @description Static convenience method that constructs a new instance and performs the
     *              request payment callout with a typed request, returning an untyped map.
     * @param rq Typed request body describing the payment.
     * @return Untyped map of the gateway response enriched with nswCppPaymentURL and nswCppStatusCode.
     */
    public static Map<String, Object> requestPayment(Request rq) {
        NSWCPPCalloutRequestPayment rp = new NSWCPPCalloutRequestPayment();
        return rp.callout(rq);
    }

    /**
     * @description Static convenience method that accepts a loosely-typed map as the request body,
     *              serialises it to JSON, deserialises it into a typed Request, then performs the callout.
     *              Useful when the caller constructs the request body dynamically.
     * @param rqmap Map representation of the request body. Supported keys mirror the Request fields:
     *              productDescription, amount, customerReference, agencyTransactionId, etc.
     * @return Untyped map of the gateway response enriched with nswCppPaymentURL and nswCppStatusCode.
     */
    public static Map<String, Object> requestPayment(Map<String, Object> rqmap) {
        String jsonString = JSON.serialize(rqmap, true);
        Request rq = (Request) JSON.deserialize(jsonString, Request.class);
        return requestPayment(rq);
    }

    /**
     * @description Thrown when a request payment callout is invoked with insufficient
     *              or malformed parameters.
     */
    public class MalformedCallException extends Exception {}
}
