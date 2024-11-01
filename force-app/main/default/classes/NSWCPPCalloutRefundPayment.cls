public class NSWCPPCalloutRefundPayment extends NSWCPPCallout {
    static final String HTTP_ENDPOINT = '/api/payments/{paymentReference}/refund';
    static final String HTTP_VERB = 'POST';

    @JsonAccess(serializable='always')
    public class Request {
        public Decimal amount; // mandatory 0-1000000 with 2 decimals
        public String refundReason; // optional
    }

    public class InvocableRequest {
        @InvocableVariable(label='Payment reference')
        public String paymentReference; // mandatory
        @InvocableVariable(label='Refund amount')
        public Decimal amount; // mandatory 0-1000000 with 2 decimals
        @InvocableVariable(label='Refund reason')
        public String refundReason; // optional
    }


    @JsonAccess(serializable='always')
    public class Response {
        @InvocableVariable(label='Refund reference')
        public String refundReference;
        @InvocableVariable(label='Duplicate indicator')
        public Boolean duplicate;
        @InvocableVariable(label='Failure reason')
        public String failureReason;

        @InvocableVariable(label='Error')
        public String error;
        @InvocableVariable(label='Message')
        public String message;
        @InvocableVariable(label='Messages')
        public List<String> messages;
        @InvocableVariable(label='Status Code (always present)')
        public Integer nswCppStatusCode;
    }

    public NSWCPPCalloutRefundPayment () {
        super();
    }

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

    public Map<String, Object> calloutMap(Map<String, String> urlParams, Request rq) {
        HttpResponse rs = super.callout(mergeParams(HTTP_ENDPOINT, urlParams), HTTP_VERB, rq);
        Integer rc = rs.getStatusCode();
        Map<String, Object> rv;

        rv = (Map<String, Object>) JSON.deserializeUntyped(rs.getBody());
        rv.put('nswCppStatusCode', rc);
        
        return rv;
    }

    public Response callout(Map<String, String> urlParams, Request rq) {
        HttpResponse rs = super.callout(mergeParams(HTTP_ENDPOINT, urlParams), HTTP_VERB, rq);
        Integer rc = rs.getStatusCode();
        Response rv;

        rv = (Response) JSON.deserialize(rs.getBody(), Response.class);
        rv.nswCppStatusCode = rc;
        
        return rv;
    }

    static public Response refundPayment(Map<String, String> urlParams, Request rq) {
        NSWCPPCalloutRefundPayment rp = new NSWCPPCalloutRefundPayment();
        return rp.callout(urlParams, rq);
    }

    static public Response refundPayment(Map<String, String> urlParams, Map<String, Object> rqmap) {
        String jsonString = JSON.serialize(rqmap, true);
        Request rq = (Request) JSON.deserialize(jsonString, Request.class);
        return refundPayment(urlParams, rq);
    }

    public class MalformedCallException extends Exception {}
}
