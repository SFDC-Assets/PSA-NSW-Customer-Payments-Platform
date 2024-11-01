/**
 * @description Complete a payment as a result of a back-end callback service call from NSW CPP
 *              as per step D in the sequence diagram: grab public key, verify JWS signature,
 *              match with the pending payment in the database and persist a step.
 * @see NSWCPPServicePaymentCompletion
 * @author E. Schweitzer
 */

/* TODO: Security Review by Paul Lucas
    The following would be executed by the guest user
    as a continuation of the Apex Rest service NSWCPPServicePaymentCompletion 
    The guest user cannot be granted any user access rights anyway.
    This is a narrow-band, very controlled operation.
*/

@SuppressWarnings('PMD.ApexCRUDViolation, PMD.AvoidGlobalModifier')
global without sharing class NSWCPPOperationComplete {
    final static String SETTINGS_CATEGORY_COMPLETION = 'Completion';
    final static String SETTINGS_PUBLICKEY = 'PublicKey';
    final static String CLAIM_CARD = 'card';
    final static String CLAIM_BPAY = 'bPay';

    /**
      * @description public point of entry for this class, sequences all the steps
      *              required to register a payment completion: grab NSW CPP public key,
      *              validate the JWS signature and invoke the database part.
      * @param compactJWS signed JWT provided by NSW CPP as part of the payment callback
      * @return Id of the persisted NSWCPPPaymentStep__c
      * @throws NoPublicKeyException when the public key cannot be found in settings
      * @throws InvalidJWSException when the JWS does not add up
      * @throws UnmatchedPaymentRefException if the completed payment cannot be matched to 
      *               a pending payment based on the payment reference
      */
    public static Id completePayment(String compactJWS) {
        Map<String, String> settings = NSWCPPSettings.getSettingsMapForCategory(SETTINGS_CATEGORY_COMPLETION);
        String publicKey = NSWCPPSettings.getSettingFromMap(SETTINGS_PUBLICKEY, settings);

        if (publicKey == null) {
            throw new NoPublicKeyException('Could not find ' + SETTINGS_PUBLICKEY + ' in settings.');
        }

        Auth.JWT verifiedJWS;
        
        try {
            verifiedJWS = Auth.JWTUtil.validateJWTWithKey(compactJWS, publicKey);
        } catch (Auth.JWTValidationException e) {
            throw new InvalidJWSException('JWS does not have a valid signature.');
        }

        return completePayment(verifiedJWS);
    } 

    /**
      * @description persist details of the payment using claims packaged in the JWT:
      *              grab additional card or bPay object claims, match with a pending
      *              payment record based on the payment reference and persist a 
      *              NSWCPPPaymentStep__c record with all details for auditability.
      *              JWT payload is persisted for technical auditability but would not
      *              necessarily have to be once accelerator matures or if data volumes
      *              become a concern.
      * @param jwt the payload of the verified JWS
      * @return the recordId of the persisted NSWCPPPaymentStep__c 
      * @throws UnmatchedPaymentRefException if the payment reference could not be matched
      */
    @TestVisible
    private static Id completePayment(Auth.JWT jwt) {
        Id cpsRecordTypeId = NSWCPPOperation.getRecordTypeIdByName(NSWCPPOperation.STATUS_COMPLETED);
        Map<String, Object> claims = jwt.getAdditionalClaims();

        /*
         * deal with a bug in JWT class which does not deserialize claims when they're objects 
         */

        Object card = claims.get(CLAIM_CARD);
        if (card instanceof String) {
            claims.put(CLAIM_CARD, JSON.deserializeUntyped((String) card));
        }

        Object bPay = claims.get(CLAIM_BPAY);
        if (bPay instanceof String) {
            claims.put(CLAIM_BPAY, JSON.deserializeUntyped((String) bPay));
        }

        /* End */

        Map<String, Object> bPayMap = (Map<String, Object>) claims.get(CLAIM_BPAY);
        Map<String, Object> cardMap = (Map<String, Object>)claims.get(CLAIM_CARD);

        String paymentReference = String.valueOf(claims.get('paymentReference'));

        List<NSWCPPPayment__c> cpList = [
            SELECT Id, PaymentReference__c
            FROM NSWCPPPayment__c
            WHERE PaymentReference__c = :paymentReference 
                AND Status__c = :NSWCPPOperation.STATUS_PENDING
            LIMIT 1
            FOR UPDATE
        ];

        if (cpList.size() == 0) {
            // TODO: place in an exception queue of some sort vs throwing an exception -- current idea, invoke a flow whose details are parameterised so that the Accelerator user can decide how those exceptions get handled (e.g. case)
            throw new UnmatchedPaymentRefException();
        }

        NSWCPPPayment__c cp = cpList[0];

        cp.AccountToken__c = String.valueOf(claims.get('accountToken'));
        cp.PaymentCompletionReference__c = String.valueOf(claims.get('paymentCompletionReference'));
        cp.PaymentMethod__c = String.valueOf(claims.get('paymentMethod'));
        cp.PaymentReference__c = paymentReference;
        cp.Status__c = NSWCPPOperation.STATUS_COMPLETED;

        NSWCPPPaymentStep__c step = new NSWCPPPaymentStep__c(
            Name = NSWCPPOperation.STATUS_COMPLETED,
            Payment__c = cp.Id,
            RecordTypeId = cpsRecordTypeId,
            AccountToken__c = String.valueOf(claims.get('accountToken')),
            Amount__c = (Decimal) claims.get('amount'),
            BankReference__c = String.valueOf(claims.get('bankReference')),
            BPayBillerCode__c = bPayMap != null ? String.valueOf(bPayMap.get('billerCode')) : null,
            BPayCRN__c = bPayMap != null ? String.valueOf(bPayMap.get('crn')) : null,
            BPayProcessingDate__c = bPayMap != null ? Date.valueOf(bPayMap.get('processingDate')) : null,
            CardLast4Digits__c = cardMap != null ? String.valueOf(cardMap.get('last4Digits')) : null,
            CardPresent__c = cardMap != null ? Boolean.valueOf(cardMap.get('cardPresent')) : null,
            CardType__c = cardMap != null ? String.valueOf(cardMap.get('cardType')) : null,
            EmailAddress__c = String.valueOf(claims.get('emailAddress')),
            PaymentCompletionReference__c = String.valueOf(claims.get('paymentCompletionReference')),
            PaymentMethod__c = String.valueOf(claims.get('paymentMethod')),
            PaymentReference__c = paymentReference,
            Surcharge__c = (Decimal) claims.get('surcharge'),
            SurchargeAbsorbed__c = (Decimal) claims.get('absorbedSurcharge'),
            SurchargeGST__c = (Decimal) claims.get('surchargeGST'),
            Status__c = NSWCPPOperation.STATUS_COMPLETED,
            Type__c = NSWCPPOperation.TYPE_PAYMENT,
            Payload__c = jwt.toJSONString()
        );


        insert step;
        update cp;

        return cp.Id;
    }

    public class NoPublicKeyException extends Exception {}
    public class InvalidJWSException extends Exception {}
    public class UnmatchedPaymentRefException extends Exception {}
}