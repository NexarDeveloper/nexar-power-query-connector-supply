
# Nexar Power Connector

The Nexar Power Connector enables you to access your pre-existing reporting data from right within Power BI.  You can populate Power BI with your most recent 100 reports without leaving Power BI.
If you are not set up with reports, please contact support@nexar.com or your business account manager. 

This connector is supported on the Windows platform only and the versions supported are Microsoft Power BI Desktop.  Specifically, the version tested 2.124.1052.0 32-bit (December 2023).

## Pre-requisites
If you are not set up with reports, please contact support@nexar.com or your business account manager. 
From them, you will need:
1. Your company ID
2. Your login details for nexar.com
3. You will need to add the following URL to the Redirect URLs in the Nexar App that you are using: https://oauth.powerbi.com/views/oauthredirect.html

## Installation
1. Download the nexar-power-query-connector.mez file
2. If you do not already have it, create the folder: \Documents\Power BI Desktop\Custom Connectors
3. Place the mez file in: \Documents\Power BI Desktop\Custom Connectors
4. Open Microsoft Power BI Desktop > Get data > search 'Nexar' > Nexar_Connector (Beta) (Custom) ![](docs/connector.png?raw=true)
5. Click, Connect
6. Enter your company ID, and click OK
![](docs/companyId.png?raw=true)
7. Click, Sign In and a log in via a pop-up for Nexar. Click, Connect
![](docs/signin.png?raw=true)
9. A summary of your reports will load. Click, OK, and they should load into Power BI.

### Troubleshooting
If you see following error, please check your company ID and try again.
![](docs/error.png?raw=true)

### Improvements
  - Feel free to request improvements by raising a "New issue" on the GitHub page.
  - Better still, feel free to prepare a Pull Request and Altium will review your changes and either accept them or get back to you.
  - Alternatively, you can contact us at support@nexar.com and a member of our team will be in touch.
  - Happy coding!