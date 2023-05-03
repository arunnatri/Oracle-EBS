--
-- XXDO_ORD_IMP_CRCTNS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:12 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_ORD_IMP_CRCTNS_PKG"
AS
    /**********************************************************************************************************
          file name    : XXDO_ORD_IMP_CRCTNS_PKG
          created by   : INFOSYS
          purpose      : To handle the stucked order in interface table.
         ****************************************************************************
         Modification history:
        *****************************************************************************
            NAME:         XXDO_ORD_IMP_CRCTNS_PKG
            PURPOSE:      To handle the stucked order in interface table.

            REVISIONS:
            Version        Date        Author           Description
            ---------  ----------  ---------------  ------------------------------------
            1.01        05/18/2018    INFOSYS      1. CCR0007229 - DOE Order Import Interface screen enhancement
            1.02        06/27/2019    Gaurav       1. CCR0008057 - LAD and Cancel date update on iface line
            1.03        08/24/2021    Gaurav       1. CCR0009483 - VAS Automation Enablement for Oracle DOE Screen
       *********************************************************************
       *********************************************************************/

    PROCEDURE REPROCESS_DELETE_ORDERS (P_OUT_CHR_RET_MESSAGE OUT NOCOPY VARCHAR2, P_OUT_NUM_RET_STATUS OUT NOCOPY NUMBER, P_REQ_ID_STR OUT NOCOPY VARCHAR2, P_USER_ID IN NUMBER, P_RESP_ID IN NUMBER, P_RESP_APPL_ID IN NUMBER
                                       , P_ORG_ID IN NUMBER, P_ORIG_SYS_DOCUMENT IN xxd_btom_oeheader_tbltype, P_OPERATION IN VARCHAR2)
    AS
        L_OUT_CHR_RET_MESSAGE      VARCHAR2 (100) := P_OUT_CHR_RET_MESSAGE;
        L_OUT_NUM_RET_STATUS       NUMBER := P_OUT_NUM_RET_STATUS;
        L_ORG_ID                   NUMBER := P_ORG_ID;
        --   L_ORIG_SYS_DOCUMENT              VARCHAR2(1000) := P_ORIG_SYS_DOCUMENT;
        L_OPERATION                VARCHAR2 (1000) := P_OPERATION;
        L_REQUEST_ID               NUMBER := 0;
        L_APPLICATION_SHORT_NAME   VARCHAR2 (10) := 'XXDO';
        V_CONCAT                   VARCHAR2 (1000);
        l_err_flag                 VARCHAR2 (1) := 'N';
        l_cnt                      NUMBER := 0;
    BEGIN
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'Start XXDO_ORD_IMP_CRCTNS_PRC procedure');
        APPS.FND_GLOBAL.APPS_INITIALIZE (USER_ID        => P_USER_ID,
                                         RESP_ID        => P_RESP_ID,
                                         RESP_APPL_ID   => P_RESP_APPL_ID);

        IF p_operation = 'REPROCESS'
        THEN
            BEGIN
                FND_FILE.PUT_LINE (FND_FILE.output,
                                   'Below Records Got Reprocessed ');

                FOR I IN P_ORIG_SYS_DOCUMENT.FIRST ..
                         P_ORIG_SYS_DOCUMENT.LAST
                LOOP
                    UPDATE oe_lines_iface_all
                       SET error_flag = NULL, request_id = NULL, /**begin changes for ver 1.02**/
                                                                 ATTRIBUTE1 = TO_CHAR (fnd_date.canonical_to_date (P_ORIG_SYS_DOCUMENT (i).attribute2), 'YYYY/MM/DD'), -- cancel data
                           REQUEST_DATE = fnd_date.canonical_to_date (P_ORIG_SYS_DOCUMENT (i).attribute1), latest_acceptable_date = fnd_date.canonical_to_date (P_ORIG_SYS_DOCUMENT (i).attribute2) --  cancel date is LAD
                                                                                                                                                                                                   /**End changes for ver 1.02**/
                                                                                                                                                                                                   , pricing_date = fnd_date.canonical_to_date (P_ORIG_SYS_DOCUMENT (i).attribute1) -- ver 1.03 pricing_date same as that of RD
                     WHERE     ORIG_SYS_DOCUMENT_REF =
                               P_ORIG_SYS_DOCUMENT (i).attribute10
                           AND org_id = L_ORG_ID;

                    UPDATE oe_headers_iface_all
                       SET error_flag = NULL, request_id = NULL, ATTRIBUTE1 = TO_CHAR (TO_DATE (P_ORIG_SYS_DOCUMENT (i).attribute2, 'YYYY/MM/DD'), 'YYYY/MM/DD'),
                           REQUEST_DATE = TO_DATE (P_ORIG_SYS_DOCUMENT (i).attribute1, 'YYYY/MM/DD HH24:MI:SS') -- Added for CCR0007229
                                                                                                               , pricing_date = fnd_date.canonical_to_date (P_ORIG_SYS_DOCUMENT (i).attribute1) -- ver 1.03 pricing_date same as that of RD
                     WHERE     ORIG_SYS_DOCUMENT_REF =
                               P_ORIG_SYS_DOCUMENT (i).attribute10
                           AND org_id = L_ORG_ID;



                    l_cnt   := l_cnt + 1;

                    FND_FILE.PUT_LINE (
                        FND_FILE.output,
                           'Reprocessed value of ORIG_SYS_DOCUMENT_REF is: '
                        || P_ORIG_SYS_DOCUMENT (i).attribute10);
                END LOOP;

                COMMIT;
                p_out_chr_ret_message   :=
                    'Selected orders reprocessed successsfully.';
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_num_ret_status    := 1;
                    p_out_chr_ret_message   :=
                           'Unexpected Error while reprocessing the orders: '
                        || SQLERRM;

                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                        'Error in REPROCESS Operation ' || SQLERRM);
                    l_err_flag              := 'Y';
            END;
        END IF;


        IF p_operation = 'DELETE'
        THEN
            BEGIN
                FND_FILE.PUT_LINE (FND_FILE.output,
                                   'Below Records Got Deleted ');

                FOR I IN P_ORIG_SYS_DOCUMENT.FIRST ..
                         P_ORIG_SYS_DOCUMENT.LAST
                LOOP
                    DELETE FROM
                        oe_headers_iface_all
                          WHERE     ORIG_SYS_DOCUMENT_REF =
                                    P_ORIG_SYS_DOCUMENT (i).attribute10
                                AND org_id = L_ORG_ID;

                    DELETE FROM
                        oe_lines_iface_all
                          WHERE     ORIG_SYS_DOCUMENT_REF =
                                    P_ORIG_SYS_DOCUMENT (i).attribute10
                                AND org_id = L_ORG_ID;

                    l_cnt   := l_cnt + 1;

                    FND_FILE.PUT_LINE (
                        FND_FILE.output,
                           'Deleted value of ORIG_SYS_DOCUMENT_REF is: '
                        || P_ORIG_SYS_DOCUMENT (i).attribute10);
                END LOOP;

                COMMIT;
                p_out_chr_ret_message   :=
                    'Selected orders deleted successsfully.';
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_num_ret_status    := 1;
                    p_out_chr_ret_message   :=
                           'Unexpected Error while deleting the orders: '
                        || SQLERRM;

                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                        'Error in DELETE Operation ' || SQLERRM);
                    l_err_flag              := 'Y';
            END;
        END IF;


        FND_FILE.PUT_LINE (FND_FILE.output,
                           'Total Processed Records : ' || l_cnt);
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_num_ret_status   := 1;
            p_out_chr_ret_message   :=
                   'Unexpected Error while reprocessing or deleting the orders: '
                || SQLERRM;
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Exception raised in REPROCESS_DELETE_ORDERS procedure : '
                || SQLERRM);
            DBMS_OUTPUT.PUT_LINE (
                   'Exception raised in REPROCESS_DELETE_ORDERS procedure : '
                || SQLERRM);
    END REPROCESS_DELETE_ORDERS;


    PROCEDURE DELETE_IFACE_LINES (P_OUT_CHR_RET_MESSAGE OUT NOCOPY VARCHAR2, P_OUT_NUM_RET_STATUS OUT NOCOPY NUMBER, P_REQ_ID_STR OUT NOCOPY VARCHAR2, P_USER_ID IN NUMBER, P_RESP_ID IN NUMBER, P_RESP_APPL_ID IN NUMBER
                                  , P_ORG_ID IN NUMBER, P_ORIG_SYS_LINE_REF IN xxd_btom_oeline_tbltype, P_ORIG_SYS_DOCUMENT IN VARCHAR2)
    AS
        L_OUT_CHR_RET_MESSAGE   VARCHAR2 (100) := P_OUT_CHR_RET_MESSAGE;
        L_OUT_NUM_RET_STATUS    NUMBER := P_OUT_NUM_RET_STATUS;
        L_ORIG_SYS_DOCUMENT     VARCHAR2 (50) := P_ORIG_SYS_DOCUMENT;
        L_ORG_ID                NUMBER := P_ORG_ID;
        L_REQUEST_ID            NUMBER := 0;
        V_CONCAT                VARCHAR2 (1000);
    BEGIN
        SAVEPOINT DEL_IFACE_LINE_SP;

        FOR I IN P_ORIG_SYS_LINE_REF.FIRST .. P_ORIG_SYS_LINE_REF.LAST
        LOOP
            DELETE FROM
                OE_LINES_IFACE_ALL
                  WHERE ORIG_SYS_LINE_REF =
                        P_ORIG_SYS_LINE_REF (I).attribute10;
        END LOOP;

        /* DELETE from OE_LINES_IFACE_ALL
                          where ORIG_SYS_LINE_REF IN (SELECT *
                                    FROM TABLE (P_ORIG_SYS_LINE_REF));*/
        COMMIT;
        P_OUT_CHR_RET_MESSAGE   := 'Selected Lines deleted successfully.';
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK TO DEL_IFACE_LINE_SP;
            l_out_num_ret_status   := 1;
            l_out_chr_ret_message   :=
                'Unexpected Error while deleting selected Lines: ' || SQLERRM;
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Exception raised in DELETE_IFACE_LINES procedure : '
                || SQLERRM);
            DBMS_OUTPUT.PUT_LINE (
                   'Exception raised in DELETE_IFACE_LINES procedure : '
                || SQLERRM);
    END DELETE_IFACE_LINES;
END XXDO_ORD_IMP_CRCTNS_PKG;
/
