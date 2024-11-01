@isTest
private class NSWCPPSettings_Test {
    final static String SETTINGS_CATEGORY_COMPLETION = 'Completion';
    final static String SETTINGS_PUBLICKEY = 'PublicKey';

    @isTest
    static void itReturnsACategoryIfItExists() {
        Test.startTest();
        Map<String, String> settings = NSWCPPSettings.getSettingsMapForCategory(SETTINGS_CATEGORY_COMPLETION);
        Test.stopTest();

        /* Perform tests */
        /* ------------- */

        System.assertNotEquals(null, settings, 'There should be a map for category ' + SETTINGS_CATEGORY_COMPLETION);
        System.assertNotEquals(0, settings.size(), 'There should be entries.');
    }

    @isTest
    static void itReturnsNullIfCategoryDoesNotExist() {
        Test.startTest();
        Map<String, String> settings = NSWCPPSettings.getSettingsMapForCategory('Random123');
        Test.stopTest();

        /* Perform tests */
        /* ------------- */

        System.asserNottEquals(null, settings, 'There should be a map.');
        System.assertEquals(0, settings.size(), 'There should be no entries.');
    }

    @isTest
    static void itReturnsValueWhenSet() {
        Test.startTest();
        Map<String, String> settings = NSWCPPSettings.getSettingsMapForCategory(SETTINGS_CATEGORY_COMPLETION);
        Test.stopTest();

        String value = NSWCPPSettings.getSettingFromMap(SETTINGS_PUBLICKEY, settings);

        /* Perform tests */
        /* ------------- */

        System.assertNotEquals(null, value, 'There should be a value for ' + SETTINGS_PUBLICKEY);
    }

    @isTest
    static void itReturnsNoValueWhenNoSet() {
        Test.startTest();
        String value = NSWCPPSettings.getSettingSingle('RANDOM.123');
        Test.stopTest();


        /* Perform tests */
        /* ------------- */

        System.assertEquals(null, value, 'There should not be a value for RANDOM.123.');
    }
}