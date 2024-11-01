public class NSWCPPClientUtilsGetUUID {
    public class Request {
        @InvocableVariable(label='Prefix' required=false)
        public String prefix;
    }

    @InvocableMethod(
        category='NSW CPP Client' 
        label='Get UUID' 
        description='Get a unique transaction ID.'
    )
    public static List<String> getUUID(List<Request> prefix) {
        List<String> rv = new List<String>();

        for (Request singlePrefix : prefix) {
            rv.add(getUUID(singlePrefix.prefix));
        }

        return rv;
    }

    public static String getUUID() {
        return getUUID('');
    } 

    public static String getUUID(String prefix) {
        return (prefix == null ? '' : prefix) + UUID.randomUUID().toString();
    }
}