public class NSWCPPCalloutGetPaymentStatus extends NSWCPPCallout {
    static final String HTTP_ENDPOINT = '/api/payments/{paymentReference}/status';
    static final String HTTP_VERB = 'GET';

    @JsonAccess(serializable='always')
    public class Card {
        public String cardType;
        public String last4Digits;
    }

    @JsonAccess(serializable='always')
    public class BPay {
        public String billerCode;
        public String crn;
        public Date processingDate;
    }

    @JsonAccess(serializable='always')
    public class AgencyCompletionPayment {
        public String paymentMethod;
        public String paymentReference;
        public String paymentCompletionReference;
        public String bankReference;
        public Decimal amount;
        public Decimal surcharge;
        public Decimal surchargeGst;
        public String agencyTransactionId;
        public Card card;
        public BPay bPay;
    }

    @JsonAccess(serializable='always')
    public class Refund {
        public String refundStatus;
        public Decimal amount;
        public String refundReference;
        public DateTime createdTimeStamp;
    }

    @JsonAccess(serializable='always')
    public class Response {
        public String paymentReference;
        public String paymentStatus;
        public String referenceNumber;
        public AgencyCompletionPayment agencyCompletionPayment;
        public Boolean isRefundable;
        public List<Refund> refundList;

        public String error;
        public String message;
        public List<String> messages;
        public Integer nswCppStatusCode;
    }

    public NSWCPPCalloutGetPaymentStatus () {
        super();
    }

    public Map<String, Object> calloutMap(Map<String, String> urlParams) {
        HttpResponse rs = super.callout(mergeParams(HTTP_ENDPOINT, urlParams), HTTP_VERB, null);
        Integer rc = rs.getStatusCode();
        Map<String, Object> rv;

        rv = (Map<String, Object>) JSON.deserializeUntyped(rs.getBody());
        rv.put('nswCppStatusCode', rc);
        
        return rv;
    }

    public Response callout(Map<String, String> urlParams) {
        HttpResponse rs = super.callout(mergeParams(HTTP_ENDPOINT, urlParams), HTTP_VERB, null);
        Integer rc = rs.getStatusCode();
        Response rv;

        rv = (Response) JSON.deserialize(rs.getBody(), Response.class);
        rv.nswCppStatusCode = rc;        
        return rv;
    }

    static public Response getPaymentStatus(Map<String, String> urlParams) {
        NSWCPPCalloutGetPaymentStatus gps = new NSWCPPCalloutGetPaymentStatus();
        return gps.callout(urlParams);
    }

    public class MalformedCallException extends Exception {}

}
