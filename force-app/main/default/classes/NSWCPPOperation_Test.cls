@isTest(seeAllData=true)
private class NSWCPPOperation_Test {
    @isTest
    static void itReturnsAnIdForLegitimateRecordType() {
        Test.startTest();
        Id completedRtId = NSWCPPOperation.getRecordTypeIdByName(NSWCPPOperation.STATUS_COMPLETED);
        Test.stopTest();

        System.assertNotEquals(null, completedRtId, 'Completed should return a record type Id.');
    }

    @isTest
    static void itReturnsNullForOtherRecordTypes() {
        Test.startTest();
        Id nullRtId = NSWCPPOperation.getRecordTypeIdByName('PeregrineTook');
        Test.stopTest();

        System.assertEquals(null, nullRtId, 'PeregrineTook should not return a record type Id.');
    }

}