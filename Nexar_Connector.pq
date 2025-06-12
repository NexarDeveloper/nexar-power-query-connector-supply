// This file contains your Data Connector logic
[Version = "1.0.0"]
section Nexar_Connector;

//
//Client ID and Secrets
//
client_id = Text.FromBinary(Extension.Contents("client_id"));
client_secret = "";


//
//Nexar Auth
//
//Nexar Prod
OAuthBaseUrl = "https://identity.nexar.com/connect/";
ApiUrl = "https://api.nexar.com/graphql";

AuthorizeUrl = Uri.Combine(OAuthBaseUrl, "authorize");
TokenUrl = Uri.Combine(OAuthBaseUrl, "token");



// OAuth2 scope
scope_prefix = "";
scopes = {
    "profile email openid user.details design.domain supply.domain offline_access"
};

// The sample provides two code_challenge_method examples: "plain" and "S256".
code_challenge_method = "S256";

// Other OAuth settings
windowWidth = 720;
windowHeight = 1024;

// This is the expected Redirect URI for OAuth flows to work in the Power BI service.
//This needs to be added to the Redirect URLs in the Nexar App that the customer is using
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";

//
// Data Source definition - defines the overall connection logic and way the Power Query interacts with the data source
//
[DataSource.Kind="Nexar_Connector", Publish="Nexar_Connector.Publish"]
shared Nexar_Connector.Contents = (companyId as text) =>
    let
        accessToken = Extension.CurrentCredential()[access_token],
        url = "https://api.nexar.com/graphql",
        //Nexar Report Example
        companyId = companyId, //Text.FromBinary(Extension.Contents("company_id")),
        contents = GetReports(companyId, accessToken, url),    
        source = contents
    in
        contents;


// Data Source Kind description - specifies how the Power Query should connect to the data source
Nexar_Connector = [
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Refresh = Refresh
        ]
    ],
    Label = "Nexar Authentication" //Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
Nexar_Connector.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/"
];


StartLogin = (resourceUrl, state, display) =>
    let
        // We'll generate our code verifier using Guids
        plainTextCodeVerifier = Text.NewGuid() & Text.NewGuid(),
        codeVerifier =
            if (code_challenge_method = "plain") then
                plainTextCodeVerifier
            else if (code_challenge_method = "S256") then
                Base64Url.Encode(Crypto.CreateHash(CryptoAlgorithm.SHA256, Text.ToBinary(plainTextCodeVerifier)))
            else
                error "Unexpected code_challenge_method",

        AuthorizeUrl = AuthorizeUrl
            & "?"
            & Uri.BuildQueryString(
                [
                    client_id = client_id,
                    response_type = "code",
                    scope = GetScopeString(scopes, scope_prefix), //"design.domain, user.access, offline_access",
                    code_challenge_method = code_challenge_method,
                    code_challenge = codeVerifier,
                    state = state,
                    redirect_uri = redirect_uri
                ]
            )
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            // Need to roundtrip this value to FinishLogin
            Context = plainTextCodeVerifier
        ];

// The code verifier will be passed in through the context parameter.
FinishLogin = (context, callbackUri, state) =>
    let
        Parts = Uri.Parts(callbackUri)[Query]
    in
        TokenMethod(Parts[code], "authorization_code", context);

// Verifier is optional to support both the original FinishLogin call
// (which has a verifier) and the Refresh call (which does not).
TokenMethod = (code, grant_type, optional verifier) =>
    let
        codeVerifier = if (verifier <> null) then [code_verifier = verifier] else [],
        codeParameter = if (grant_type = "authorization_code") then [code = code] else [refresh_token = code],
        query = codeVerifier
            & codeParameter
            //& gqlquery
            & [
                client_id = client_id,
                // Native client flows should not require a client_secret when using PKCE, but some still do.
                client_secret = client_secret,
                grant_type = grant_type,
                redirect_uri = redirect_uri
                
            ],
        // Set this if your API returns a non-2xx status for login failures
        // ManualHandlingStatusCodes = {400, 403}
        ManualHandlingStatusCodes = {},
        Response = Web.Contents(
            TokenUrl,
            [
                Content = Text.ToBinary(Uri.BuildQueryString(query)),
                Headers = [
                    #"Content-type" = "application/x-www-form-urlencoded",
                    #"Accept" = "application/json"
                ],
                ManualStatusHandling = ManualHandlingStatusCodes
            ]
        ),
        Parts = Json.Document(Response)
    in
        // check for error in response
        if (Parts[error]? <> null) then
            error Error.Record(Parts[error], Parts[message]?)
        else
            Parts;


//
//Get Reports from the reporting portal 
//
GetReports = (companyId, accessToken, url) => 
    let

        vUrl = url,
        vHeaders =[
        #"Method"="POST",
        #"Content-Type"="application/json",
        #"Authorization"=Text.Combine({"Bearer ", accessToken})
        ],
        //GQL Query to get report
        query = "{""query"":""query test {  datRepReports( first: 100    companyId: \""" & companyId & "\""  where: { createdDate: { gte: \""2020-01-01\""  } }  ){    nodes {      title      id    }  }}""}",
        vContent=Text.ToBinary(query),
        Source = Web.Contents(vUrl, [Headers=vHeaders, Content=vContent]),
        #"JSON" = Json.Document(Source),
        data = #"JSON"[data],
        datRepReports = data[datRepReports],
        nodes = datRepReports[nodes],
        #"Converted to Table" = Table.FromList(nodes, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Added Custom" = Table.AddColumn(#"Converted to Table", "Custom", each [Column1][title]),
        #"Added Custom1" = Table.AddColumn(#"Added Custom", "url", each [Column1][id]),
        #"Renamed Columns" = Table.RenameColumns(#"Added Custom1",{{"Custom", "Title"}, {"url", "ID"}}),
        #"Invoked Custom Function" = Table.AddColumn(#"Renamed Columns", "Reports", each GetReportFromReportId([ID], companyId,accessToken, url))
        
    in
        #"Invoked Custom Function";
        
//
//Get Reports from Report ID
//
GetReportFromReportId = (reportId, companyId, accessToken, url) =>
    let
        vUrl = url,
        vHeaders =[
        #"Method"="POST",
        #"Content-Type"="application/json",
        #"Authorization"=Text.Combine({"Bearer ", accessToken})
        ],
        query = "{""query"":""query GetReportDownloadUrl {  datRepDownloadableFile(    companyId: \""" & companyId & "\"",    reportId: \""" & reportId & "\""  ) {    downloadUrl  }}""}",
        vContent=Text.ToBinary(query),
        Source = Web.Contents(vUrl,  [Headers=vHeaders, Content=vContent]),
        #"JSON" = Json.Document(Source),  
        data = #"JSON"[data],
        datRepDownloadableFile = data[datRepDownloadableFile],
        downloadURL = datRepDownloadableFile[downloadUrl],
        csv = Csv.Document(Web.Contents(downloadURL),[Delimiter=",", Encoding=1252, QuoteStyle=QuoteStyle.None])
    in
        csv;

    

Value.IfNull = (a, b) => if a <> null then a else b;

GetScopeString = (scopes as list, optional scopePrefix as text) as text =>
    let
        prefix = Value.IfNull(scopePrefix, ""),
        addPrefix = List.Transform(scopes, each prefix & _),
        asText = Text.Combine(addPrefix, " ")
    in
        asText;

Refresh = (resourceUrl, refresh_token) => TokenMethod(refresh_token, "refresh_token");
AccessToken = (resourceUrl, access_token) => TokenMethod(access_token, "access_token");

Base64Url.Encode = (s) => Text.Replace(Text.Replace(Text.BeforeDelimiter(Binary.ToText(s,BinaryEncoding.Base64),"="),"+","-"),"/","_");

Nexar_Connector.Icons = [
    Icon16 = { Extension.Contents("Nexar_Connector16.png"), Extension.Contents("Nexar_Connector20.png"), Extension.Contents("Nexar_Connector24.png"), Extension.Contents("Nexar_Connector32.png") },
    Icon32 = { Extension.Contents("Nexar_Connector32.png"), Extension.Contents("Nexar_Connector40.png"), Extension.Contents("Nexar_Connector48.png"), Extension.Contents("Nexar_Connector64.png") }
];
