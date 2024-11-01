@isTest
private class NSWCPPCalloutRefundPayment_Test {
    @isTest
    static void itReturnsSensibleDataForRequestedRefund() {
        Test.setMock(HttpCalloutMock.class, new NSWCPPCallout_Mock(
            NSWCPPCallout_Mock.MockType.REFUNDPAYMENT_OK
        ));

        Test.startTest();
        NSWCPPCalloutRefundPayment.Request rq = new NSWCPPCalloutRefundPayment.Request();
        rq.amount = 23.35;
        rq.refundReason = 'some reason';

        NSWCPPCalloutRefundPayment.Response rs = NSWCPPCalloutRefundPayment.refundPayment(
            new Map<String, String> {
                'paymentReference' => 'GPP-DIG-5YRG9-I9QWSSLnDeMb5UFA'
            },
            rq
        );
        Test.stopTest();

        System.assertEquals(202, rs.nswCppStatusCode, 'Should have 202 http code.');
        System.assertEquals('N7NSAZMYGR', rs.refundReference, 'Should have refundReference');
        System.assertEquals(false, rs.duplicate, 'Should not be duplicate');
        System.assertEquals('', rs.failureReason, 'Should have no failureReason');
    }
    
    @isTest
    static void itReturnsErrorForFailedPayment() {
        Test.setMock(HttpCalloutMock.class, new NSWCPPCallout_Mock(
            NSWCPPCallout_Mock.MockType.REFUNDPAYMENT_FAIL
        ));

        Test.startTest();
        NSWCPPCalloutRefundPayment.Request rq = new NSWCPPCalloutRefundPayment.Request();
        rq.amount = 23.35;
        rq.refundReason = 'some reason';
        NSWCPPCalloutRefundPayment.Response rs = NSWCPPCalloutRefundPayment.refundPayment(
            new Map<String, String> {
                'paymentReference' => 'GPP-DIG-5YRG9-I9QWSSLnDeMb5UFA'
            },
            rq
        );
        Test.stopTest();

        System.assertEquals(403, rs.nswCppStatusCode, 'Should have 403 http code.');
        System.assertEquals('Validation failed', rs.failureReason, 'Should have the right error');
    }

    @isTest
    static void itReturnsErrorForRandomPayment() {
        Test.setMock(HttpCalloutMock.class, new NSWCPPCallout_Mock(
            NSWCPPCallout_Mock.MockType.REFUNDPAYMENT_NOTFOUND
        ));

        Test.startTest();
        NSWCPPCalloutRefundPayment.Request rq = new NSWCPPCalloutRefundPayment.Request();
        rq.amount = 23.35;
        rq.refundReason = 'some reason';
        NSWCPPCalloutRefundPayment.Response rs = NSWCPPCalloutRefundPayment.refundPayment(
            new Map<String, String> {
                'paymentReference' => 'GPP-DIG-5YRG9-I9QWSSLnDeMb5UFC'
            },
            rq
        );
        Test.stopTest();

        System.assertEquals(404, rs.nswCppStatusCode, 'Should have 404 http code.');
        System.assertEquals('Payment not found', rs.failureReason, 'Should have the right error');
    }
}