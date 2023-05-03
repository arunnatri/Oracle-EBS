--
-- XXDO_CUSTOMER_CONTACT_CONV_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:40 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXDO_CUSTOMER_CONTACT_CONV_PKG
AS
    /*******************************************************************************
    * Program Name : XXDO_CUSTOMER_CONTACT_CONV_PKG
    * Language     : PL/SQL
    * Description  : This package will convert customer contact.
    *
    * History      :
    *
    * WHO                  WHAT              DESC                       WHEN
    * -------------- ---------------------------------------------- ---------------
    *                      1.0              Initial Version          14-MAY-2015
    *******************************************************************************/
    GC_YESFLAG                    VARCHAR2 (1) := 'Y';
    GC_NOFLAG                     VARCHAR2 (1) := 'N';
    GC_NEW                        VARCHAR2 (3) := 'N';
    GC_API_SUCC                   VARCHAR2 (1) := 'S';
    GC_API_ERROR                  VARCHAR2 (10) := 'E';
    GC_INSERT_FAIL                VARCHAR2 (1) := 'F';
    GC_PROCESSED                  VARCHAR2 (1) := 'P';
    GN_LIMIT                      NUMBER := 10000;
    GN_RETCODE                    NUMBER;
    GN_SUCCESS                    NUMBER := 0;
    GN_WARNING                    NUMBER := 1;
    GN_ERROR                      NUMBER := 2;
    GD_SYS_DATE                   DATE := SYSDATE;
    GN_CONC_REQUEST_ID            NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
    GN_USER_ID                    NUMBER := FND_GLOBAL.USER_ID;
    GN_LOGIN_ID                   NUMBER := FND_GLOBAL.LOGIN_ID;
    GN_PARENT_REQUEST_ID          NUMBER;
    GN_REQUEST_ID                 NUMBER := NULL;
    GN_ORG_ID                     NUMBER := FND_GLOBAL.ORG_ID;

    GC_CODE_POINTER               VARCHAR2 (250);
    GN_PROCESSCNT                 NUMBER;
    GN_SUCCESSCNT                 NUMBER;
    GN_ERRORCNT                   NUMBER;
    GC_CREATED_BY_MODULE          VARCHAR2 (100) := 'TCA_V1_API';
    GC_SECURITY_GRP               VARCHAR2 (20) := 'ORG';
    GC_NO_FLAG           CONSTANT VARCHAR2 (10) := 'N';
    GC_YES_FLAG          CONSTANT VARCHAR2 (10) := 'Y';
    GC_DEBUG_FLAG                 VARCHAR2 (10);

    GC_VALIDATE_STATUS   CONSTANT VARCHAR2 (20) := 'VALIDATED';
    GC_ERROR_STATUS      CONSTANT VARCHAR2 (20) := 'ERROR';
    GC_NEW_STATUS        CONSTANT VARCHAR2 (20) := 'NEW';
    GC_PROCESS_STATUS    CONSTANT VARCHAR2 (20) := 'PROCESSED';
    GC_INTERFACED        CONSTANT VARCHAR2 (20) := 'INTERFACED';

    GC_EXTRACT_ONLY      CONSTANT VARCHAR2 (20) := 'EXTRACT'; --'EXTRACT ONLY';
    GC_VALIDATE_ONLY     CONSTANT VARCHAR2 (20) := 'VALIDATE'; -- 'VALIDATE ONLY';
    GC_LOAD_ONLY         CONSTANT VARCHAR2 (20) := 'LOAD';      --'LOAD ONLY';

    GE_API_EXCEPTION              EXCEPTION;

    TYPE CUST_MAPPING_REC_TYPE IS RECORD
    (
        OLD_CUSTOMER_ID           NUMBER (15),
        NEW_CUSTOMER_ID           NUMBER (15),
        OLD_PARTY_ID              NUMBER (15),
        NEW_PARTY_ID              NUMBER (15),
        OLD_PROFILE_ID            NUMBER (15),
        NEW_PROFILE_ID            NUMBER (15),
        OLD_LOCATION_ID           NUMBER (15),
        NEW_LOCATION_ID           NUMBER (15),
        OLD_PARTY_SITE_ID         NUMBER (15),
        NEW_PARTY_SITE_ID         NUMBER (15),
        OLD_CUST_SITE_ID          NUMBER (15),
        NEW_CUST_SITE_ID          NUMBER (15),
        OLD_SITE_USE_ID           NUMBER (15),
        NEW_SITE_USE_ID           NUMBER (15),
        LAST_UPDATE_DATE          DATE,
        LAST_UPDATED_BY           NUMBER (15),
        CREATION_DATE             DATE,
        CREATED_BY                NUMBER (15),
        ATTRIBUTE_CATEGORY        VARCHAR2 (30),
        ATTRIBUTE1                VARCHAR2 (150),
        ATTRIBUTE2                VARCHAR2 (150),
        ATTRIBUTE3                VARCHAR2 (150),
        ATTRIBUTE4                VARCHAR2 (150),
        ATTRIBUTE5                VARCHAR2 (150),
        ATTRIBUTE6                VARCHAR2 (150),
        ATTRIBUTE7                VARCHAR2 (150),
        ATTRIBUTE8                VARCHAR2 (150),
        ATTRIBUTE9                VARCHAR2 (150),
        ATTRIBUTE10               VARCHAR2 (150),
        REQUEST_ID                NUMBER (15),
        PROGRAM_APPLICATION_ID    NUMBER (15),
        PROGRAM_ID                NUMBER (15),
        PROGRAM_UPDATE_DATE       DATE,
        ORG_ID                    NUMBER (15),
        RECORD_STATUS             VARCHAR2 (30),
        ERROR_MESSAGE             VARCHAR2 (3000),
        INACTIVE_SITE_USEID       NUMBER
    );

    --Start of adding new prc by BT Technology Team on 25-May-2015--
    PROCEDURE Customer_main_proc (x_retcode OUT NUMBER, x_errbuf OUT VARCHAR2, p_process IN VARCHAR2, p_org_name IN VARCHAR2, p_customer_classification IN VARCHAR2, p_debug_flag IN VARCHAR2
                                  , p_no_of_process IN NUMBER);

    PROCEDURE customer_child (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_debug_flag IN VARCHAR2 DEFAULT 'N', p_action IN VARCHAR2, p_org_name IN VARCHAR2, --    p_validation_level    IN     VARCHAR2,
                                                                                                                                                             p_batch_id IN NUMBER
                              , p_parent_request_id IN NUMBER);

    --End of adding new prc by BT Technology Team on 25-May-2015--


    --  PROCEDURE CREATE_CONTACTS_RECORDS(PN_CUSTOMER_ID      IN NUMBER,
    --                                    P_PARTY_ID          IN NUMBER,
    --                                    P_ADDRESS_ID        IN NUMBER,
    --                                    P_PARTY_SITE_ID     IN NUMBER,
    --                                    P_CUST_ACCOUNT_ID   IN NUMBER,
    --                                    P_CUST_ACCT_SITE_ID IN NUMBER);

    PROCEDURE LOG_RECORDS (P_DEBUG VARCHAR2, P_MESSAGE VARCHAR2);
END XXDO_CUSTOMER_CONTACT_CONV_PKG;
/
