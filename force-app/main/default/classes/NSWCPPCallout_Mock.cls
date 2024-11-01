@isTest
public with sharing class NSWCPPCallout_Mock implements HttpCalloutMock {
    public enum MockType { 
        REQUESTPAYMENT_NODUP_OK, 
        REQUESTPAYMENT_DUP_OK, 
        REQUESTPAYMENT_KO_AGENCYNOTFOUND, 
        GETPAYMENT_OK_REQUESTED,
        GETPAYMENT_OK_CANCELLED,
        GETPAYMENT_OK_PAID,
        GETPAYMENT_OK_REFUNDED,
        GETPAYMENT_KO_NOTFOUND,
        REFUNDPAYMENT_OK,
        REFUNDPAYMENT_FAIL,
        REFUNDPAYMENT_NOTFOUND
    }

    MockType type;

    public NSWCPPCallout_Mock(MockType type) {
        this.type = type;
    }

    public HttpResponse respond(HttpRequest rq) {

        HttpResponse rs = new HttpResponse();
        rs.setHeader('Content-Type', 'application/json');

        switch on type {
            when REQUESTPAYMENT_NODUP_OK {
                rs.setBody('{"paymentReference": "GPP-DIG--fniMBvQTqugmPC3APGjXQ","duplicate": false}');
                rs.setStatusCode(200);
            }
            when REQUESTPAYMENT_DUP_OK {
                rs.setBody('{"paymentReference": "GPP-DIG--fniMBvQTqugmPC3APGjXQ","duplicate": true}');
                rs.setStatusCode(200);
            }
            when REQUESTPAYMENT_KO_AGENCYNOTFOUND {
                rs.setBody('{' +
                    '"error": "AGENCY_NOT_FOUND",' +
                    '"messages": [ "Not registered to request payment" ],' +
                    '"message": "Not registered to request payment"' +
                '}');
                rs.setStatusCode(403);
            }
            when GETPAYMENT_OK_REQUESTED {
                rs.setBody('{' +
                    '"paymentReference": "GPP-DIG--fniMBvQTqugmPC3APGjXQ",' +
                    '"paymentStatus": "REQUESTED",' +
                    '"referenceNumber": null,' +
                    '"agencyCompletionPayment": null,' +
                    '"isRefundable": false,' +
                    '"refundList": []' +
                '}');
                rs.setStatusCode(200);
            }
            when GETPAYMENT_OK_CANCELLED {
                rs.setBody('{' +
                    '"paymentReference": "GPP-DIG-5YRG9-I9QWSSLnDeMb5UFA",' +
                    '"paymentStatus": "CANCELLED",' +
                    '"referenceNumber": null,' +
                    '"agencyCompletionPayment": null,' +
                    '"isRefundable": false,' +
                    '"refundList": []' +
                '}');
                rs.setStatusCode(200);
            }
            when GETPAYMENT_OK_PAID {
                rs.setBody('{' +
                    '"paymentReference": "GPP-DIG-5YRG9-I9QWSSLnDeMb5UFA",' +
                    '"paymentStatus": "PAID",' +
                    '"referenceNumber": "N7NSAZMYGR",' +
                    '"agencyCompletionPayment": {' +
                        '"paymentMethod":"CARD",' +
                        '"paymentReference":"GPP-DIG-5YRG9-I9QWSSLnDeMb5UFA",' +
                        '"paymentCompletionReference":"N7NSAZMYGR",' +
                        '"bankReference": "xxx",' +
                        '"amount": 123.45,' +
                        '"surcharge: 1.23,' +
                        '"surchargeGst: 0.12,' +
                        '"card": {' +
                            '"cardType":"VISA",' +
                            '"last4Digits":"1234"' +
                        '},' +
                    '},' +
                    '"isRefundable": true,' +
                    '"refundList": []' +
                '}');
                rs.setStatusCode(200);
            }
            when GETPAYMENT_OK_REFUNDED {
                rs.setBody('{' +
                    '"paymentReference": "GPP-DIG-5YRG9-I9QWSSLnDeMb5UFA",' +
                    '"paymentStatus": "PAID",' +
                    '"referenceNumber": null,' +
                    '"agencyCompletionPayment": {' +
                        '"paymentMethod":"CARD",' +
                        '"paymentReference":"GPP-DIG-5YRG9-I9QWSSLnDeMb5UFA",' +
                        '"paymentCompletionReference":"N7NSAZMYGR",' +
                        '"bankReference": "xxx",' +
                        '"amount": 123.45,' +
                        '"surcharge: 1.23,' +
                        '"surchargeGst: 0.12,' +
                        '"card": {' +
                            '"cardType":"VISA",' +
                            '"last4Digits":"1234"' +
                        '},' +
                    '},' +
                    '"isRefundable": true,' +
                    '"refundList": [{' +
                        '"refundStatus":"REFUND_APPLIED",' +
                        '"amount":23.45,' +
                        '"refundReference":"N7NSAZMYGR",' +
                        '"createdTimeStamp":"2024-01-01T02:00:00"' +
                    '}]' +
                '}');
                rs.setStatusCode(200);
            }
            when GETPAYMENT_KO_NOTFOUND {
                rs.setBody('{' +
                    '"error": "PaymentReferenceNotFoundException",' +
                    '"messages": [ "Payment being requested does not exist" ],' +
                    '"message": "Payment being requested does not exist"' +
                '}');
                rs.setStatusCode(404);
            }
            when REFUNDPAYMENT_OK {
                rs.setBody('{' +
                    '"refundReference": "N7NSAZMYGR",' +
                    '"duplicate": false,' +
                    '"failureReason": ""' +
                '}');
                rs.setStatusCode(202);
            }
            when REFUNDPAYMENT_FAIL {
                rs.setBody('{"failureReason":"Validation failed"}');
                rs.setStatusCode(403);
            }
            when REFUNDPAYMENT_NOTFOUND {
                rs.setBody('{"failureReason":"Payment not found"}');
                rs.setStatusCode(404);
            }
        }

        return rs;
    }
}