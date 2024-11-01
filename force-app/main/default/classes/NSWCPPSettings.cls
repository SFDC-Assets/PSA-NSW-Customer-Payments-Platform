/**
 * @author Emmanuel Schweitzer / Salesforce Global Public Sector
 *
 * @description Handles settings for the NSW CPP asset; insulates code from the underlying
 * custom metadata storage. Settings are classified using a category and name with the name
 * being unique across categories, but categories used to efficiently grab multiple related
 * settings in a single go.
 */
public without sharing class NSWCPPSettings {

    /**
     * @description get a Map of settings for a category given its' name.
     * @param category the name of the category to retrieve settings for
     * @return all the settings associated to the category
     */
    public static Map<String, String> getSettingsMapForCategory(String category) {
        List<NSWCPPSetting__mdt> settings = [
            SELECT DeveloperName, Category__c, Value__c
            FROM NSWCPPSetting__mdt
            WHERE Category__c = :category
            WITH SYSTEM_MODE
            LIMIT 100
        ];

        Map<String, String> settingsMap = new Map<String, String>();

        for (NSWCPPSetting__mdt setting : settings) {
            settingsMap.put(setting.DeveloperName.toLowerCase(), setting.Value__c);
        }

        return settingsMap;
    }

    /**
     * @description get a single setting from a map retrieved using getSettingsMapForCategory.
     * @param name name of the setting
     * @param categoryMap map retrieved using getSettingsMapForCategory
     * @return the value of the setting or null if not found
     */
    public static String getSettingFromMap(String name, Map<String, String> categoryMap) {
        return categoryMap.get(name.toLowerCase());
    }

    /**
     * @description get a single settings directly from the database.
     * @param name name of the setting
     * @return the value of the setting or null if not found
     */
    public static String getSettingSingle(String name) {
        List<NSWCPPSetting__mdt> settings = [
            SELECT DeveloperName, Value__c
            FROM NSWCPPSetting__mdt
            WHERE DeveloperName = :name
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        return settings.size() > 0 ? settings[0].Value__c : null;
    }
}