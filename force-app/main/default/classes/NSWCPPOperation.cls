/**
 * @description Utility class for Operations with status values and record type getting.
 * @author E. Schweitzer
 */
public abstract class NSWCPPOperation {
    public static final String STATUS_INITIATED = 'Initiated';
    public static final String STATUS_PENDING = 'Pending';
    public static final String STATUS_COMPLETED = 'Completed';
    public static final String STATUS_FAILED = 'Failed';
    public static final String TYPE_PAYMENT = 'Payment';
    public static final String TYPE_REFUND = 'Refund';

    /**
      * @description Returns the recordType Id of a Payment Step by name
      * @param name Name of the record type
      * @return the recordType Id or null if there was no match.
      */
    public static Id getRecordTypeIdByName(String name) {
        return Schema.SObjectType.NSWCPPPaymentStep__c
            .getRecordTypeInfosByName()
            .get(name)
            ?.getRecordTypeId();
    }
}