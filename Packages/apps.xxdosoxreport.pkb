--
-- XXDOSOXREPORT  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:36 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXDOSOXREPORT
IS
    FUNCTION XXDOC2BDATAPOINT (P_DATA_POINT_NAME   VARCHAR2,
                               P_CASE_FOLDER_ID    NUMBER)
        RETURN VARCHAR2
    AS
        RET_VALUE   VARCHAR2 (100);
    BEGIN
        SELECT DATA_POINT_VALUE
          INTO RET_VALUE
          FROM AR_CMGT_CF_DTLS ACCD, AR_CMGT_DATA_POINTS_TL ACDP
         WHERE     ACCD.DATA_POINT_ID = ACDP.DATA_POINT_ID
               AND ACDP.LANGUAGE = USERENV ('LANG')
               AND DATA_POINT_NAME = P_DATA_POINT_NAME
               AND CASE_FOLDER_ID = P_CASE_FOLDER_ID;

        RETURN RET_VALUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RET_VALUE   := ' ';
            RETURN RET_VALUE;
    END XXDOC2BDATAPOINT;


    FUNCTION AFTERREPORT (CUSTOMER_NAME VARCHAR2)
        RETURN BOOLEAN
    IS
        L_RESULT   BOOLEAN;
        L_REQ_ID   NUMBER;
    BEGIN
        COMMIT;
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Inside POST START');


        IF CUSTOMER_NAME IS NOT NULL
        THEN
            L_REQ_ID   :=
                FND_REQUEST.SUBMIT_REQUEST (
                    APPLICATION   => 'XDO',                     -- APPLICATION
                    PROGRAM       => 'XDOBURSTREP',                 -- PROGRAM
                    DESCRIPTION   => 'Bursting',                -- DESCRIPTION
                    ARGUMENT1     => 'N',
                    ARGUMENT2     => FND_GLOBAL.CONC_REQUEST_ID,
                    -- ARGUMENT1
                    ARGUMENT3     => 'Y'                          -- ARGUMENT2
                                        );
        END IF;

        RETURN TRUE;
    END AFTERREPORT;

    FUNCTION SMTP_HOST
        RETURN VARCHAR2
    IS
        SMPT_SERVER   VARCHAR2 (200);
    BEGIN
        SELECT FSCPV.PARAMETER_VALUE SMTP_HOST
          INTO SMPT_SERVER
          FROM FND_SVC_COMP_PARAMS_TL FSCPT, FND_SVC_COMP_PARAM_VALS FSCPV, FND_SVC_COMPONENTS FSC
         WHERE     FSCPT.PARAMETER_ID = FSCPV.PARAMETER_ID
               AND FSCPV.COMPONENT_ID = FSC.COMPONENT_ID
               AND FSCPT.DISPLAY_NAME = 'Outbound Server Name'
               AND FSC.COMPONENT_NAME = 'Workflow Notification Mailer';

        RETURN SMPT_SERVER;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.PUT_LINE (
                'Unable to get SMTP Server Name for emailing');
    END SMTP_HOST;
END XXDOSOXREPORT;
/
