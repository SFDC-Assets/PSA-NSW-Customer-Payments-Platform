@isTest
private class NSWCPPOperationComplete_Test {
    static final Map<String, Object> receivedRaw = new Map<String, Object> {
        'absorbedSurcharge' => 0.0, 
        'agencyTransactionId' => 'ceca3ef6-a1d0-4eb5-af84-a06a06d4df5c',
        'amount' => 33.0, 
        'bankReference' => '1123851865',
        'card' => new Map<String, Object> {
            'cardType' => 'VISA',
            'last4Digits' => '6459',
            'cardPresent' => false
        },
        'paymentCompletionReference' => 'YWVZ64HY9J', 
        'paymentMethod' => 'CARD',
        'paymentReference' => 'GPP-DIG-UvYd96GzRlu-_J-pOto3kg',
        'surcharge' => 0.13,
        'surchargeGST' =>  0.01
    };

    static final String COMPACT_JWS = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjIyMTgyMzkwMjIsIm5hbWUiOiJUb21hc3ogWndpZXJ6Y2hvxYQifQ.t3VhQ7QsILDuV_HNFSMI-Fb2FoT7fuzalpS5AH8A9c0';

    static void logPaymentStep(NSWCPPPaymentStep__c value) {
        System.debug('> logPaymentStep');
        System.debug('  AccountToken__c: ' + value.AccountToken__c);
        System.debug('  AgencyTransactionID__c: ' + value.AgencyTransactionID__c);
        System.debug('  Amount__c: ' + value.Amount__c);
        System.debug('  BankReference__c: ' + value.BankReference__c);
        System.debug('  BPayBillerCode__c: ' + value.BPayBillerCode__c);
        System.debug('  BPayCRN__c: ' + value.BPayCRN__c);
        System.debug('  BPayProcessingDate__c: ' + value.BPayProcessingDate__c);
        System.debug('  CardLast4Digits__c: ' + value.CardLast4Digits__c);
        System.debug('  CardPresent__c: ' + value.CardPresent__c);
        System.debug('  CardType__c: ' + value.CardType__c);
        System.debug('  EmailAddress__c: ' + value.EmailAddress__c);
        System.debug('  PaymentCompletionReference__c: ' + value.PaymentCompletionReference__c);
        System.debug('  PaymentMethod__c: ' + value.PaymentMethod__c);
        System.debug('  PaymentReference__c: ' + value.PaymentReference__c);
        System.debug('  Surcharge__c: ' + value.Surcharge__c);
        System.debug('  SurchargeAbsorbed__c: ' + value.SurchargeAbsorbed__c);
        System.debug('  SurchargeGST__c: ' + value.SurchargeGST__c);
    }

    /* Cannot compare AgencyTransactionIds as it's not available for all steps/operations */
    static boolean compare(NSWCPPPaymentStep__c expected, 
                           NSWCPPPaymentStep__c received) {
        logPaymentStep(expected);
        logPaymentStep(received);
        return expected.AccountToken__c == received.AccountToken__c &&
               expected.Amount__c == received.Amount__c &&
               expected.BankReference__c == received.BankReference__c &&
               expected.BPayBillerCode__c == received.BPayBillerCode__c &&
               expected.BPayCRN__c == received.BPayCRN__c &&
               expected.BPayProcessingDate__c == received.BPayProcessingDate__c &&
               expected.CardLast4Digits__c == received.CardLast4Digits__c &&
               expected.CardPresent__c == received.CardPresent__c &&
        	   expected.CardType__c == received.CardType__c &&
               expected.EmailAddress__c == received.EmailAddress__c &&
               expected.PaymentCompletionReference__c == received.PaymentCompletionReference__c &&
        	   expected.PaymentMethod__c == received.PaymentMethod__c &&
               expected.PaymentReference__c == received.PaymentReference__c &&
               expected.Surcharge__c == received.Surcharge__c &&
               expected.SurchargeAbsorbed__c == received.SurchargeAbsorbed__c &&
               expected.SurchargeGST__c == received.SurchargeGST__c;
    }
    
    @isTest
    static void itProcessesAValidCardPaymentCompletion() {
        Auth.JWT jwt = new Auth.JWT();
        jwt.setSub((String) receivedRaw.get('paymentReference'));
        jwt.setAdditionalClaims(receivedRaw);

        NSWCPPPaymentStep__c expected = new NSWCPPPaymentStep__c(
            SurchargeAbsorbed__c = 0.0, 
            AccountToken__c = null,
            AgencyTransactionID__c = 'ceca3ef6-a1d0-4eb5-af84-a06a06d4df5c',
            Amount__c = 33.0, 
            BankReference__c = '1123851865',
            CardType__c = 'VISA',
            CardLast4Digits__c = '6459',
            CardPresent__c = false,
            EmailAddress__c = null,
            PaymentCompletionReference__c = 'YWVZ64HY9J', 
            PaymentMethod__c = 'CARD',
            PaymentReference__c = 'GPP-DIG-UvYd96GzRlu-_J-pOto3kg',
            Surcharge__c = 0.13,
            SurchargeGST__c = 0.01
        );

        Test.startTest();

        NSWCPPPayment__c initialPayment = new NSWCPPPayment__c(
            AgencyTransactionID__c = 'ceca3ef6-a1d0-4eb5-af84-a06a06d4df5c',
            Amount__c = 33.0,
            PaymentReference__c = 'GPP-DIG-UvYd96GzRlu-_J-pOto3kg',
            ProductDescription__c = 'Paintball venue licence',
            Status__c = NSWCPPOperation.STATUS_PENDING
        );

        insert initialPayment;

        NSWCPPOperationComplete.completePayment(jwt);

        NSWCPPPayment__c updatedPayment = [
            SELECT Id, AmountPaid__c, Balance__c, Status__c 
            FROM NSWCPPPayment__c
            WHERE Id = :initialPayment.Id
        ];

        List<NSWCPPPaymentStep__c> paymentSteps = [
            SELECT Id, AccountToken__c, AgencyTransactionID__c, Amount__c, BankReference__c, 
                BPayBillerCode__c, BPayCRN__c, BPayProcessingDate__c,
                CardType__c, CardLast4Digits__c, CardPresent__c, 
                EmailAddress__c, PaymentCompletionReference__c, PaymentMethod__c, PaymentReference__c,
                Surcharge__c, SurchargeAbsorbed__c, SurchargeGST__c, Status__c, RecordType.Name
            FROM NSWCPPPaymentStep__c
        ];

        Test.stopTest();

        System.assertEquals(
            NSWCPPOperation.STATUS_COMPLETED, 
            updatedPayment.Status__c, 
            'Payment should have completed.');
            
        System.assertEquals(
            0.0, 
            updatedPayment.Balance__c, 
            'Balance should be zero.');

        System.assertEquals(
            1, 
            paymentSteps.size(), 
            'There should be only one payment step');

        NSWCPPPaymentStep__c ps = paymentSteps[0];
        Boolean comparison = compare(ps, expected);

        System.assertEquals(
            NSWCPPOperation.STATUS_COMPLETED, 
            ps.Status__c, 
            'Payment step should have \'Completed\' status.');

        System.assertEquals(
            NSWCPPOperation.STATUS_COMPLETED, 
            ps.RecordType.Name, 
            'Payment step should have \'Completed\' record type.');

        System.assertEquals(
            true, 
            comparison, 
            'Payment step should have all field values from jwt mapped correctly.');
    }

    @isTest
    static void itThrowsAnExceptionForUnmatchedPayments() {
        Auth.JWT jwt = new Auth.JWT();
        jwt.setSub((String) receivedRaw.get('paymentReference'));
        jwt.setAdditionalClaims(receivedRaw);

        Boolean exceptionThrown = false;
        Test.startTest();

        try {
            NSWCPPOperationComplete.completePayment(jwt);
        } catch(NSWCPPOperationComplete.UnmatchedPaymentRefException e) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'UnmatchedPaymentException should be thrown for unmatched payments');
    }

    @isTest
    static void itThrowsAnExceptionWhenJWSDoesNotAddUp() {
        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            NSWCPPOperationComplete.completePayment(COMPACT_JWS);
        } catch (NSWCPPOperationComplete.InvalidJWSException e) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'InvalidJWSException should be thrown when JWS does not add up');
    }

}