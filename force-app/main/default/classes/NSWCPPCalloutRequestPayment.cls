global class NSWCPPCalloutRequestPayment extends NSWCPPCallout {
    static final String HTTP_ENDPOINT = '/api/request-payment';
    static final String HTTP_VERB = 'POST';

    @JsonAccess(serializable='always')
    global class Discount {
        public Decimal amount;
        public String code;
        public String reference;
    }

    @JsonAccess(serializable='always')
    global class Disbursement {
        public Decimal amount;
        public String agencyCode;
    }

    @JsonAccess(serializable='always')
    global class Request {
        @InvocableVariable(label='Product Description' required=true)
        public String productDescription; // mandatory, maximum length of 250
        @InvocableVariable(required=true label='Amount')
        public Decimal amount; 			  // mandatory 0-1000000 with 2 decimals
        public List<Discount> discounts;
        @InvocableVariable(label='Customer Reference Number')
        public String customerReference; // optional, maximum length of 250
        @InvocableVariable(required=true label='Agency Transaction Id')
        public String agencyTransactionId; // mandatory, maximum length of 50
        public String subAgencyCode { get; set; } // optional - deprecating
        public String callingSystem { get; set; }
        public Boolean setupRecurringPayment { get; set; } // optional
        public List<Disbursement> disbursements;
        public Map<String, Object> transactionReferences;

        public Request add(Disbursement disbursement) {
            if (this.disbursements == null) {
                this.disbursements = new List<Disbursement>();
            }

            this.disbursements.add(disbursement);
            return this;
        }

        public Request add(Discount discount) {
            if (this.discounts == null) {
                this.discounts = new List<Discount>();
            }

            this.discounts.add(discount);
            return this;
        }
    }

    @JsonAccess(serializable='always')
    global class Response {
        @InvocableVariable(label='NSW CPP Payment Reference Number')
        public String paymentReference;
        @InvocableVariable(label='Duplicate request flag')
        public Boolean duplicate;
        @InvocableVariable(label='NSW CPP Payment URL')
        public String nswCppPaymentURL;
        @InvocableVariable(label='Status Code (always present)')
        public Integer nswCppStatusCode;

        Response() {
            this.paymentReference = null;
        }

        Response(Map<String, Object> rsMap) {
            this.paymentReference = (String) rsMap.get('paymentReference');
            this.duplicate = (Boolean) rsMap.get('duplicate');
            this.nswCppPaymentURL = (String) rsMap.get('nswCppPaymentURL');
            this.nswCppStatusCode = (Integer) rsMap.get('nswCppStatusCode');
        }
    }

    public NSWCPPCalloutRequestPayment () {
        super();
    }
    
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

    static public Map<String, Object> requestPayment(Request rq) {
        NSWCPPCalloutRequestPayment rp = new NSWCPPCalloutRequestPayment();
        return rp.callout(rq);
    }

    static public Map<String, Object> requestPayment(Map<String, Object> rqmap) {
        String jsonString = JSON.serialize(rqmap, true);
        Request rq = (Request) JSON.deserialize(jsonString, Request.class);
        return requestPayment(rq);
    }

    public class MalformedCallException extends Exception {}
}