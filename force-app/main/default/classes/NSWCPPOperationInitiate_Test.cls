@isTest
private class NSWCPPOperationInitiate_Test {
    static String refForNumber(String stub, Integer i) {
        return stub + '_' + String.valueOf(i);
    }

    @isTest
    static void mustInitiateOperationCorrectly() {
        final String stub = 'MyUniquePaymentReference_' + System.now().getTime();
        final Integer numberRecords = 5;

        /* Prepare records */
        /* --------------- */

        Test.startTest();

        List<NSWCPPOperationInitiate.Request> rqList = new List<NSWCPPOperationInitiate.Request>();
        
        for (Integer i = 1; i <= numberRecords; i++) {
            NSWCPPOperationInitiate.Request rq = new NSWCPPOperationInitiate.Request();
            rq.agencyTransactionId = refForNumber(stub, i);
            rq.amount = Math.Random() * 100.0;
            rq.customerReference = 'CustRef ' + i;
            rq.productDescription = 'Item ' + i;
            rq.setupRecurringPayment = false;
            rq.accountToken = null;
            
            rqList.add(rq);    
        }
        
        List<Id> idList = NSWCPPOperationInitiate.initiatePayment(rqList);


        Test.stopTest();

        /* Perform tests */
        /* ------------- */

        Map<Id, NSWCPPPayment__c> paymentMap = new Map<Id, NSWCPPPayment__c>([
            SELECT Id, Status__c, AgencyTransactionId__c
            FROM NSWCPPPayment__c
            WHERE Id IN :idList
        ]);

        System.assertEquals(numberRecords, paymentMap.size(), 'All payment records should be accounted for');

        for (Id paymentId : idList) {
            NSWCPPPayment__c payment = paymentMap.get(paymentId);
            
            System.assertNotEquals(
                null,
                payment,
                'All initiated payments should be accounted for'
            );
            
            System.assertEquals(
                NSWCPPOperation.STATUS_INITIATED, 
                payment.Status__c, 
                'State should be initiated'
            );
        }
        
        for (Integer i = 0; i < rqList.size(); i++) {
            NSWCPPOperationInitiate.Request rq = rqList[i];
            Id rs = idList[i];
            NSWCPPPayment__c payment = paymentMap.get(rs);
            
            System.assertEquals(
                rq.agencyTransactionId,
                payment.AgencyTransactionId__c,
                'Initiate operation should return Ids in the right order.'
            );
        }
    }
    
    @isTest
    static void nullSrpShouldBeConvertedToNo() {
        Id rsId = NSWCPPOperationInitiate.initiatePayment(
	        'nullSrpShouldBeConvertedToFalse',
        	Math.Random() * 100,
            'SomeProduct',
            'CustRef1',
        	null,
        	null
        );
        
        NSWCPPPayment__c payment = [
            SELECT Id, Status__c, SetupRecurringPayment__c
            FROM NSWCPPPayment__c
            WHERE Id = :rsId
            LIMIT 1
        ];
        
        System.assertEquals(
            'No',
            payment.SetupRecurringPayment__c,
            'Shoud have a No SetupRecurringPayment attribute value.'
        );

    }
}