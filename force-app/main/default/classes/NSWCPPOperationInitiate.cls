/**
 * @description Initiates a payment via NSW CPP as per step A in the sequence diagram: 
                create a payment record and persist a step.
 * @author E. Schweitzer
 */

/* TODO: Security Review by Paul Lucas
    The following would be executed by the guest user
    as a continuation of the Apex Rest service NSWCPPServicePaymentCompletion 
    The guest user cannot be granted any user access rights anyway.
    This is a narrow-band, very controlled operation.
*/

@SuppressWarnings('PMD.ApexCRUDViolation, PMD.AvoidGlobalModifier, PMD.ExcessiveParameterList')
global without sharing class NSWCPPOperationInitiate {
    public class Request {
        @InvocableVariable(label='Agency Transaction ID' required=true)
        public String agencyTransactionId;
        @InvocableVariable(label='Amount' required=true)
        public Decimal amount;
        @InvocableVariable(label='Product Description' required=true)
        public String productDescription;
        @InvocableVariable(label='Customer Reference' required=false)
        public String customerReference;
        @InvocableVariable(label='Account Token' required=false)
        public String accountToken;
        @InvocableVariable(label='Setup Recurring Payment' required=false)
        public Boolean setupRecurringPayment;
    }

    /**
      * @description Invocable method that initiate a list of payments.
      * @param payment a list of Requests containing the Agency transaction Id, amount,
      *                product description, customer reference, account token and flag
      *                for a recurring payment.
      * @return a list of Record Id of the initiated payment.
      */
    @InvocableMethod(
        category='NSW CPP' 
        label='Initiate Payment' 
        description='Initiates a NSW CPP Payment.'
    )
    public static List<Id> initiatePayment(List<Request> payment) {
        Id cpsRecordTypeId = NSWCPPOperation.getRecordTypeIdByName(NSWCPPOperation.STATUS_INITIATED);

        List<NSWCPPPayment__c> cpList = new List<NSWCPPPayment__c>();
        for (Request item : payment) {
            Boolean srp = item.setupRecurringPayment;

            if (srp == null) {
                srp = false;
            }

            cpList.add(
                new NSWCPPPayment__c(
                    Name = item.agencyTransactionId,
                    AgencyTransactionID__c = item.agencyTransactionId,
                    Amount__c = item.amount,
                    ProductDescription__c = item.productDescription,
                    CustomerReference__c = item.customerReference,
                    AccountToken__c = item.accountToken,
                    SetupRecurringPayment__c = srp ? 'Yes' : 'No',
                    Status__c = NSWCPPOperation.STATUS_INITIATED
                )
            );
        }

        insert cpList;

        List<Id> rv = new List<Id>();
        List<NSWCPPPaymentStep__c> cpsList = new List<NSWCPPPaymentStep__c>();

        for (NSWCPPPayment__c item : cpList) {
            rv.add(item.Id);

            cpsList.add(
                new NSWCPPPaymentStep__c(
                    Name = item.Status__c,
                    Payment__c = item.Id,
                    RecordTypeId = cpsRecordTypeId,
                    AgencyTransactionID__c = item.AgencyTransactionID__c,
                    Amount__c = item.Amount__c,
                    ProductDescription__c = item.ProductDescription__c,
                    CustomerReference__c = item.CustomerReference__c,
                    AccountToken__c = item.AccountToken__c,
                    SetupRecurringPayment__c = item.SetupRecurringPayment__c,
                    Status__c = item.Status__c,
                    Type__c = NSWCPPOperation.TYPE_PAYMENT
                )
            );
        }

        insert cpsList;

        return rv;
    }

    /**
      * @description Initiates a payment.
      * @param payment a request containing the Agency transaction Id, amount,
      *                product description, customer reference, account token and flag
      *                for a recurring payment.
      * @return the record Id of the initiated payment
      */
    public static Id initiatePayment(Request payment) {
        return initiatePayment(new List<Request> { payment })[0];
    }

    /**
      * @description Initiates a payment.
      * @param agencyTransactionId the agency transaction id
      * @param amount the payment amount
      * @param productDescription the product description
      * @param customerReference the customer reference
      * @param accountToken the account token
      * @param setupRecurringPayment a flag to indicate a recurring payment
      * @return the record Id of the initiated payment
      */
    public static Id initiatePayment(
        String agencyTransactionId,
        Decimal amount,
        String productDescription,
        String customerReference,
        String accountToken,
        Boolean setupRecurringPayment
    ) {
        Request payment = new Request();

        payment.agencyTransactionId = agencyTransactionId;
        payment.amount = amount;
        payment.productDescription = productDescription;
        payment.customerReference = customerReference;
        payment.accountToken = accountToken;
        payment.setupRecurringPayment = setupRecurringPayment;

        return initiatePayment(new List<Request> { payment })[0];
    }
}