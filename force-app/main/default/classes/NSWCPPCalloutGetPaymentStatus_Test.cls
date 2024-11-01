@isTest
private class NSWCPPCalloutGetPaymentStatus_Test {
    @isTest
    static void itReturnsSensibleDataForRequestedPayment() {
        Test.setMock(HttpCalloutMock.class, new NSWCPPCallout_Mock(
            NSWCPPCallout_Mock.MockType.GETPAYMENT_OK_REQUESTED
        ));

        Test.startTest();
        NSWCPPCalloutGetPaymentStatus.Response rs = NSWCPPCalloutGetPaymentStatus.getPaymentStatus(
            new Map<String, String> {
                'paymentReference' => 'GPP-DIG--fniMBvQTqugmPC3APGjXQ'
            }
        );
        Test.stopTest();

        System.assertEquals(200, rs.nswCppStatusCode, 'Should have 200 http code.');
        System.assertEquals('REQUESTED', rs.paymentStatus, 'Should have REQUESTED status.');
    }
    
    @isTest
    static void itReturnsSensibleDataForCancelledPayment() {
        Test.setMock(HttpCalloutMock.class, new NSWCPPCallout_Mock(
            NSWCPPCallout_Mock.MockType.GETPAYMENT_OK_CANCELLED
        ));

        Test.startTest();
        NSWCPPCalloutGetPaymentStatus.Response rs = NSWCPPCalloutGetPaymentStatus.getPaymentStatus(
            new Map<String, String> {
                'paymentReference' => 'GPP-DIG-5YRG9-I9QWSSLnDeMb5UFA'
            }
        );
        Test.stopTest();

        System.assertEquals(200, rs.nswCppStatusCode, 'Should have 200 http code.');
        System.assertEquals('CANCELLED', rs.paymentStatus, 'Should have CANCELLED status.');
        System.assertEquals(null, rs.agencyCompletionPayment, 'Should have null agency completion payment.');
    }
    
    @isTest
    static void itReturnsSensibleDataForCompletedPayment() {
        Test.setMock(HttpCalloutMock.class, new NSWCPPCallout_Mock(
            NSWCPPCallout_Mock.MockType.GETPAYMENT_OK_PAID
        ));

        Test.startTest();
        NSWCPPCalloutGetPaymentStatus.Response rs = NSWCPPCalloutGetPaymentStatus.getPaymentStatus(
            new Map<String, String> {
                'paymentReference' => 'GPP-DIG-5YRG9-I9QWSSLnDeMb5UFA'
            }
        );
        Test.stopTest();

        System.assertEquals(200, rs.nswCppStatusCode, 'Should have 200 http code.');
        System.assertEquals('PAID', rs.paymentStatus, 'Should have PAID status.');
        System.assertNotEquals(null, rs.agencyCompletionPayment, 'Should have agency completion payment.');
        System.assertEquals(123.45, rs.agencyCompletionPayment.amount, 'Should have the right amount.');
    }

    @isTest
    static void itReturnsErrorForRandomPayment() {
        Test.setMock(HttpCalloutMock.class, new NSWCPPCallout_Mock(
            NSWCPPCallout_Mock.MockType.GETPAYMENT_KO_NOTFOUND
        ));

        Test.startTest();
        NSWCPPCalloutGetPaymentStatus gps = new NSWCPPCalloutGetPaymentStatus();
        Map<String, Object> rs = gps.calloutMap(
            new Map<String, String> {
                'paymentReference' => 'GPP-DIG--fniMBvQTqugmPC3APGjXQ_XYZ'
            }
        );
        Test.stopTest();

        System.assertEquals(404, rs.get('nswCppStatusCode'), 'Should have 404 http code.');
        System.assertEquals('PaymentReferenceNotFoundException', rs.get('error'), 'Should have the right error.');
    }
}