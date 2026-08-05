/**
 * @description Executes the NSW CPP refund payment API call (POST /api/payments/{paymentReference}/refund).
 *              Extends NSWCPPCallout to inherit named credential resolution, timeout/compression
 *              settings, and URL parameter merging.
 *
 *              Declared without sharing because the calling user may not have access to the custom
 *              metadata classes used for configurability. Review any changes to this class carefully.
 * 
 *              While we make this callout available for you convenience, Refunds, the associated processes and securing
 *              access to them is not part of the Accelerator.  Carefully craft your user stories and
 *              thoroughly check security aspects.
 *
 *              Exposes three entry points:
 *              - @InvocableMethod for Flow consumers.
 *              - refundPayment(Map, Request) static helper for direct Apex invocation with a typed request.
 *              - refundPayment(Map, Map) static helper for loosely-typed map-based invocation.
 *
 * @author E. Schweitzer
 * @see NSWCPPCallout
 * @see NSWCPPOperationRefund
 */
public without sharing 
class NSWCPPCalloutRefundPayment 
extends NSWCPPCallout {

    /** @description Relative URL template for the refund endpoint. The {paymentReference} placeholder
     *               is substituted at callout time via NSWCPPCallout.mergeParams. */
    static final String HTTP_ENDPOINT = '/api/payments/{paymentReference}/refund';

    /** @description HTTP verb used for the refund endpoint. */
    static final String HTTP_VERB = 'POST';

    /**
     * @description JSON-serialisable request body for the NSW CPP refund API.
     *              Serialised with null values suppressed (JSON.serialize with suppressApexObjectNulls=true).
     */
    @JsonAccess(serializable='always')
    public class Request {
        /** @description Amount to refund. Mandatory. Must be between 0 and 1,000,000 with at most 2 decimal places. */
        public Decimal amount;
        /** @description Human-readable reason for the refund. Optional. */
        public String refundReason;
    }

    /**
     * @description Input wrapper for the @InvocableMethod. Carries all parameters needed to
     *              perform a refund from a Flow or OmniScript element.
     */
    public class InvocableRequest {
        /** @description Payment reference issued by the NSW CPP gateway for the original payment. Mandatory. */
        @InvocableVariable(label='Payment reference')
        public String paymentReference;
        /** @description Amount to refund. Mandatory. Must be between 0 and 1,000,000 with at most 2 decimal places. */
        @InvocableVariable(label='Refund amount')
        public Decimal amount;
        /** @description Human-readable reason for the refund. Optional. */
        @InvocableVariable(label='Refund reason')
        public String refundReason;
    }

    /**
     * @description Typed response from the NSW CPP refund API.
     *              nswCppStatusCode is always populated with the HTTP status code.
     *              On success (HTTP 202), refundReference and duplicate are populated.
     *              On failure, error, message, and/or messages are populated by the gateway.
     */
    @JsonAccess(serializable='always')
    public class Response {
        /** @description Gateway-issued reference for the refund transaction. Populated on success. */
        @InvocableVariable(label='Refund reference')
        public String refundReference;
        /** @description True if the gateway considers this a duplicate refund request. */
        @InvocableVariable(label='Duplicate indicator')
        public Boolean duplicate;
        /** @description Reason the refund failed. Populated on failure. */
        @InvocableVariable(label='Failure reason')
        public String failureReason;
        /** @description Gateway error code. Populated on non-2xx responses. */
        @InvocableVariable(label='Error')
        public String error;
        /** @description Primary error message from the gateway. Populated on non-2xx responses. */
        @InvocableVariable(label='Message')
        public String message;
        /** @description Additional error messages from the gateway. Populated on non-2xx responses. */
        @InvocableVariable(label='Messages')
        public List<String> messages;
        /** @description HTTP status code of the gateway response. Always populated. */
        @InvocableVariable(label='Status Code (always present)')
        public Integer nswCppStatusCode;
    }

    /**
     * @description Constructs a new instance and initialises the inherited callout configuration
     *              by resolving the calling system for the current network context.
     * @throws NSWCPPCallout.NSWCPPNoCallingSystemException if no calling system is configured
     *                                                      for the current network.
     */
    public NSWCPPCalloutRefundPayment() {
        super();
    }

    /**
     * @description Invocable entry point for Flow and OmniScript consumers.
     *              Processes one refund per InvocableRequest element and returns a Response for each.
     * @param refundRequests List of InvocableRequest objects, each specifying a payment reference,
     *                       refund amount, and optional refund reason.
     * @return A list of Response objects in the same order as the input list.
     */
    @InvocableMethod(
        category='NSW CPP'
        label='Refund Payment'
        description='Refunds a payment using the NSW CPP platform.'
    )
    public static List<Response> refundPayment(List<InvocableRequest> refundRequests) {
        NSWCPPCalloutRefundPayment rp = new NSWCPPCalloutRefundPayment();

        List<Response> responses = new List<Response>();
        for (InvocableRequest irq : refundRequests) {
            Request rq = new Request();
            rq.amount = irq.amount;
            rq.refundReason = irq.refundReason;

            Response rs = refundPayment(new Map<String, String> { 'paymentReference' => irq.paymentReference }, rq);
            responses.add(rs);
        }

        return responses;
    }

    /**
     * @description Executes the refund callout and returns the raw response as an untyped map.
     *              The HTTP status code is injected into the map under the key 'nswCppStatusCode'.
     *              Use this overload when callers need access to gateway fields not modelled in Response.
     * @param urlParams Map containing 'paymentReference' to substitute into the endpoint URL template.
     * @param rq        Typed request body specifying the refund amount and optional reason.
     * @return Untyped map of the gateway response body with 'nswCppStatusCode' added.
     */
    public Map<String, Object> calloutMap(Map<String, String> urlParams, Request rq) {
        HttpResponse rs = super.callout(mergeParams(HTTP_ENDPOINT, urlParams), HTTP_VERB, rq);
        Integer rc = rs.getStatusCode();
        Map<String, Object> rv;

        rv = (Map<String, Object>) JSON.deserializeUntyped(rs.getBody());
        rv.put('nswCppStatusCode', rc);

        return rv;
    }

    /**
     * @description Executes the refund callout and returns a typed Response.
     *              The HTTP status code is set on the response via nswCppStatusCode.
     * @param urlParams Map containing 'paymentReference' to substitute into the endpoint URL template.
     * @param rq        Typed request body specifying the refund amount and optional reason.
     * @return Typed Response deserialised from the gateway response body.
     */
    public Response callout(Map<String, String> urlParams, Request rq) {
        HttpResponse rs = super.callout(mergeParams(HTTP_ENDPOINT, urlParams), HTTP_VERB, rq);
        Integer rc = rs.getStatusCode();
        Response rv;

        rv = (Response) JSON.deserialize(rs.getBody(), Response.class);
        rv.nswCppStatusCode = rc;

        return rv;
    }

    /**
     * @description Static convenience method that constructs a new instance and performs the
     *              refund callout with a typed request body.
     * @param urlParams Map containing 'paymentReference' to substitute into the endpoint URL template.
     * @param rq        Typed request body specifying the refund amount and optional reason.
     * @return Typed Response from the gateway.
     */
    public static Response refundPayment(Map<String, String> urlParams, Request rq) {
        NSWCPPCalloutRefundPayment rp = new NSWCPPCalloutRefundPayment();
        return rp.callout(urlParams, rq);
    }

    /**
     * @description Static convenience method that accepts a loosely-typed map as the request body,
     *              serialises it to JSON, deserialises it into a typed Request, then performs the callout.
     *              Useful when the caller constructs the request body dynamically.
     * @param urlParams Map containing 'paymentReference' to substitute into the endpoint URL template.
     * @param rqmap     Map representation of the request body (keys: 'amount', 'refundReason').
     * @return Typed Response from the gateway.
     */
    public static Response refundPayment(Map<String, String> urlParams, Map<String, Object> rqmap) {
        String jsonString = JSON.serialize(rqmap, true);
        Request rq = (Request) JSON.deserialize(jsonString, Request.class);
        return refundPayment(urlParams, rq);
    }

    /**
     * @description Thrown when a refund callout is invoked with insufficient or malformed parameters.
     */
    public class MalformedCallException extends Exception {}
}
