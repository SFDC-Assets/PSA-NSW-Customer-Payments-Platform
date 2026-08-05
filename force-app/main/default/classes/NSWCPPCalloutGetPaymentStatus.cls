/**
 * @description Executes the NSW CPP get payment status API call (GET /api/payments/{paymentReference}/status).
 *              Extends NSWCPPCallout to inherit named credential resolution, timeout/compression
 *              settings, and URL parameter merging.
 *
 *              Declared without sharing because the calling user may not have access to the custom
 *              metadata records used for configuration. Do not expose to unprivileged, external users.
 *
 *              Exposes two instance overloads and one static convenience method:
 *              - calloutMap(Map) returns an untyped map for callers that need raw gateway fields.
 *              - callout(Map) returns a typed Response.
 *              - getPaymentStatus(Map) static helper for direct Apex invocation.
 *
 * @author E. Schweitzer
 * @see NSWCPPCallout
 * @see NSWCPPCalloutGetPaymentStatus.Response
 */
public without sharing class NSWCPPCalloutGetPaymentStatus extends NSWCPPCallout {

    /** @description Relative URL template for the status endpoint. The {paymentReference} placeholder
     *               is substituted at callout time via NSWCPPCallout.mergeParams. */
    static final String HTTP_ENDPOINT = '/api/payments/{paymentReference}/status';

    /** @description HTTP verb used for the status endpoint. */
    static final String HTTP_VERB = 'GET';

    /**
     * @description Card payment details returned as part of AgencyCompletionPayment.
     *              Populated only when the payment method is CARD.
     */
    @JsonAccess(serializable='always')
    public class Card {
        /** @description Card scheme (e.g. VISA, MASTERCARD). */
        public String cardType;
        /** @description Last four digits of the card number used for the payment. */
        public String last4Digits;
    }

    /**
     * @description BPAY payment details returned as part of AgencyCompletionPayment.
     *              Populated only when the payment method is BPAY.
     */
    @JsonAccess(serializable='always')
    public class BPay {
        /** @description BPAY biller code for the agency. */
        public String billerCode;
        /** @description Customer reference number used for the BPAY transaction. */
        public String crn;
        /** @description Date the BPAY payment was processed by the bank. */
        public Date processingDate;
    }

    /**
     * @description Completion details for a payment that has been successfully processed.
     *              Populated on the Response when paymentStatus is PAID.
     */
    @JsonAccess(serializable='always')
    public class AgencyCompletionPayment {
        /** @description Payment method used (e.g. CARD, BPAY). */
        public String paymentMethod;
        /** @description NSW CPP payment reference for this transaction. */
        public String paymentReference;
        /** @description Agency-facing completion reference issued by the gateway. */
        public String paymentCompletionReference;
        /** @description Bank-issued reference for the transaction. */
        public String bankReference;
        /** @description Total amount paid, excluding surcharge. */
        public Decimal amount;
        /** @description Surcharge applied to the transaction. */
        public Decimal surcharge;
        /** @description GST component of the surcharge. */
        public Decimal surchargeGst;
        /** @description Agency transaction ID supplied at payment initiation. */
        public String agencyTransactionId;
        /** @description Card details. Populated when paymentMethod is CARD, null otherwise. */
        public Card card;
        /** @description BPAY details. Populated when paymentMethod is BPAY, null otherwise. */
        public BPay bPay;
    }

    /**
     * @description Details of a single refund associated with the payment.
     *              The refundList on Response may contain zero or more of these.
     */
    @JsonAccess(serializable='always')
    public class Refund {
        /** @description Current status of the refund (e.g. REFUND_APPLIED, REFUND_FAILED). */
        public String refundStatus;
        /** @description Amount refunded. */
        public Decimal amount;
        /** @description Gateway-issued reference for the refund transaction. */
        public String refundReference;
        /** @description Timestamp when the refund record was created. */
        public DateTime createdTimeStamp;
    }

    /**
     * @description Typed response from the NSW CPP get payment status API.
     *              nswCppStatusCode is always populated with the HTTP status code.
     *              On success (HTTP 200), paymentReference, paymentStatus, and isRefundable are populated.
     *              agencyCompletionPayment is populated only when paymentStatus is PAID.
     *              refundList contains zero or more Refund entries depending on refund history.
     *              On failure, error, message, and/or messages are populated by the gateway.
     */
    @JsonAccess(serializable='always')
    public class Response {
        /** @description NSW CPP payment reference for the queried payment. */
        public String paymentReference;
        /** @description Current payment status (e.g. REQUESTED, PAID, CANCELLED). */
        public String paymentStatus;
        /** @description Agency-facing reference number. Populated when paymentStatus is PAID. */
        public String referenceNumber;
        /** @description Completion details. Populated when paymentStatus is PAID, null otherwise. */
        public AgencyCompletionPayment agencyCompletionPayment;
        /** @description True when the payment is eligible for a refund. */
        public Boolean isRefundable;
        /** @description List of refunds applied to this payment. Empty list if no refunds exist. */
        public List<Refund> refundList;
        /** @description Gateway error code. Populated on non-2xx responses. */
        public String error;
        /** @description Primary error message from the gateway. Populated on non-2xx responses. */
        public String message;
        /** @description Additional error messages from the gateway. Populated on non-2xx responses. */
        public List<String> messages;
        /** @description HTTP status code of the gateway response. Always populated. */
        public Integer nswCppStatusCode;
    }

    /**
     * @description Constructs a new instance and initialises the inherited callout configuration
     *              by resolving the calling system for the current network context.
     * @throws NSWCPPCallout.NSWCPPNoCallingSystemException if no calling system is configured
     *                                                      for the current network.
     */
    public NSWCPPCalloutGetPaymentStatus() {
        super();
    }

    /**
     * @description Executes the get payment status callout and returns the raw response as an
     *              untyped map. The HTTP status code is injected under the key 'nswCppStatusCode'.
     *              Use this overload when callers need access to gateway fields not modelled in Response.
     * @param urlParams Map containing 'paymentReference' to substitute into the endpoint URL template.
     * @return Untyped map of the gateway response body with 'nswCppStatusCode' added.
     */
    public Map<String, Object> calloutMap(Map<String, String> urlParams) {
        HttpResponse rs = super.callout(mergeParams(HTTP_ENDPOINT, urlParams), HTTP_VERB, null);
        Integer rc = rs.getStatusCode();
        Map<String, Object> rv;

        rv = (Map<String, Object>) JSON.deserializeUntyped(rs.getBody());
        rv.put('nswCppStatusCode', rc);

        return rv;
    }

    /**
     * @description Executes the get payment status callout and returns a typed Response.
     *              The HTTP status code is set on the response via nswCppStatusCode.
     * @param urlParams Map containing 'paymentReference' to substitute into the endpoint URL template.
     * @return Typed Response deserialised from the gateway response body.
     */
    public Response callout(Map<String, String> urlParams) {
        HttpResponse rs = super.callout(mergeParams(HTTP_ENDPOINT, urlParams), HTTP_VERB, null);
        Integer rc = rs.getStatusCode();
        Response rv;

        rv = (Response) JSON.deserialize(rs.getBody(), Response.class);
        rv.nswCppStatusCode = rc;
        return rv;
    }

    /**
     * @description Static convenience method that constructs a new instance and performs the
     *              get payment status callout, returning a typed Response.
     * @param urlParams Map containing 'paymentReference' to substitute into the endpoint URL template.
     * @return Typed Response from the gateway.
     */
    public static Response getPaymentStatus(Map<String, String> urlParams) {
        NSWCPPCalloutGetPaymentStatus gps = new NSWCPPCalloutGetPaymentStatus();
        return gps.callout(urlParams);
    }

    /**
     * @description Thrown when the get payment status callout is invoked with insufficient
     *              or malformed parameters.
     */
    public class MalformedCallException extends Exception {}
}
