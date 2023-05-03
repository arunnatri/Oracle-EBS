--
-- XXDOGL006_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:47 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOGL006_PKG"
AS
    /******************************************************************************
       NAME: XXDOGL006_PKG
       Program NAme : Chart of Accounts Integration - Deckers

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0       02/27/2011     Shibu        1. Created this package for GL CCID Integration with Retail
       2.0       17-Feb-2016   BT Team       2. Replaced the instance PROD with EBSPROD wherever applicable.
       3.0       14-Jun-2021   BT Team       3. Modified for Oracle 19C Upgrade - Integration will be happen through Business Event
    ******************************************************************************/

    FUNCTION SEGMENT_DESC (p_chart_of_accounts_id IN NUMBER, p_segment IN VARCHAR2, p_value IN VARCHAR2)
        RETURN VARCHAR
    IS
        l_desc   fnd_flex_values_tl.description%TYPE;
    BEGIN
        IF    p_chart_of_accounts_id IS NULL
           OR p_segment IS NULL
           OR p_value IS NULL
        THEN
            RETURN ('');
        END IF;

        SELECT fvd.description
          INTO l_desc
          FROM apps.fnd_id_flex_structures_tl ffs, apps.fnd_id_flex_segments_vl fs, apps.fnd_flex_values fv,
               apps.fnd_flex_values_tl fvd
         WHERE     ffs.id_flex_num = P_CHART_OF_ACCOUNTS_ID -- Links to gl_ledgers.chart_of_accounts_id
               AND ffs.id_flex_code = 'GL#'
               AND ffs.language = USERENV ('LANG')
               AND ffs.id_flex_num = fs.id_flex_num
               AND ffs.id_flex_code = fs.id_flex_code
               AND fs.application_column_name = P_SEGMENT -- ex: SEGMENT1, SEGMENT2, etc
               AND fs.flex_value_set_id = fv.flex_value_set_id
               AND fv.flex_value = P_VALUE                -- ex: Segment Value
               AND fv.flex_value_id = fvd.flex_value_id
               AND fvd.language = USERENV ('LANG');

        RETURN (l_desc);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN ('');
    END;


    PROCEDURE MAIN (PV_ERRBUF OUT VARCHAR2, PV_RETCODE OUT VARCHAR2, PV_REPROCESS IN VARCHAR2
                    , PV_FROM_DATE IN VARCHAR2, PV_TO_DATE IN VARCHAR2)
    IS
        lv_wsdl_ip               VARCHAR2 (25);
        lv_wsdl_url              VARCHAR2 (4000);
        lv_namespace             VARCHAR2 (4000);
        lv_service               VARCHAR2 (4000);
        lv_port                  VARCHAR2 (4000);
        lv_operation             VARCHAR2 (4000);
        lv_targetname            VARCHAR2 (4000);

        lx_xmltype_in            SYS.XMLTYPE;
        lx_xmltype_out           SYS.XMLTYPE;
        lc_return                CLOB;

        LV_ERRMSG                VARCHAR2 (4000);
        LV_FROM_DATE             DATE;
        LV_TO_DATE               DATE;

        CURSOR CUR_GL_ACCOUNTS (v_coa_id       IN NUMBER,
                                PV_FROM_DATE   IN VARCHAR2,
                                PV_TO_DATE     IN VARCHAR2)
        IS
              SELECT CC.CODE_COMBINATION_ID,
                     cc.concatenated_segments
                         primary_account,
                     cc.segment1
                         attribute1,
                     cc.segment2
                         attribute2,
                     cc.segment3
                         attribute3,
                     cc.segment4
                         attribute4,
                     cc.segment5
                         attribute5,
                     cc.segment6
                         attribute6,
                     cc.segment7
                         attribute7,
                     cc.segment8
                         attribute8,
                     cc.segment9
                         attribute9,
                     cc.segment10
                         attribute10,
                     cc.segment11
                         attribute11,
                     cc.segment12
                         attribute12,
                     cc.segment13
                         attribute13,
                     cc.segment14
                         attribute14,
                     cc.segment15
                         attribute15,
                     segment_desc (v_coa_id, 'SEGMENT1', cc.segment1)
                         description1,
                     segment_desc (v_coa_id, 'SEGMENT2', cc.segment2)
                         description2,
                     segment_desc (v_coa_id, 'SEGMENT3', cc.segment3)
                         description3,
                     segment_desc (v_coa_id, 'SEGMENT4', cc.segment4)
                         description4,
                     segment_desc (v_coa_id, 'SEGMENT5', cc.segment5)
                         description5,
                     segment_desc (v_coa_id, 'SEGMENT6', cc.segment6)
                         description6,
                     segment_desc (v_coa_id, 'SEGMENT7', cc.segment7)
                         description7,
                     segment_desc (v_coa_id, 'SEGMENT8', cc.segment8)
                         description8,
                     segment_desc (v_coa_id, 'SEGMENT9', cc.segment9)
                         description9,
                     segment_desc (v_coa_id, 'SEGMENT10', cc.segment10)
                         description10,
                     segment_desc (v_coa_id, 'SEGMENT11', cc.segment11)
                         description11,
                     segment_desc (v_coa_id, 'SEGMENT12', cc.segment12)
                         description12,
                     segment_desc (v_coa_id, 'SEGMENT13', cc.segment13)
                         description13,
                     segment_desc (v_coa_id, 'SEGMENT14', cc.segment14)
                         description14,
                     segment_desc (v_coa_id, 'SEGMENT15', cc.segment15)
                         description15,
                     gl_comp.set_of_books_id
                         set_of_books_id,
                     XMLELEMENT (
                         "v1:GLCOADesc",
                         --XMLELEMENT ("v1:primary_account", cc.concatenated_segments), -- commented by BT Tech Team on 19th Feb 2015
                         XMLELEMENT ("v1:primary_account",
                                     cc.code_combination_id), -- added by BT Tech Team on 19th Feb 2015
                         XMLELEMENT ("v1:attribute1", cc.segment1),
                         XMLELEMENT ("v1:attribute2", cc.segment2),
                         XMLELEMENT ("v1:attribute3", cc.segment3),
                         XMLELEMENT ("v1:attribute4", cc.segment4),
                         XMLELEMENT ("v1:attribute5", cc.segment5),
                         XMLELEMENT ("v1:attribute6", cc.segment6),
                         XMLELEMENT ("v1:attribute7", cc.segment7),
                         XMLELEMENT ("v1:attribute8", cc.segment8),
                         XMLELEMENT ("v1:attribute9", cc.segment9),
                         XMLELEMENT ("v1:attribute10", cc.segment10),
                         XMLELEMENT ("v1:attribute11", cc.segment11),
                         XMLELEMENT ("v1:attribute12", cc.segment12),
                         XMLELEMENT ("v1:attribute13", cc.segment13),
                         XMLELEMENT ("v1:attribute14", cc.segment14),
                         XMLELEMENT ("v1:attribute15", cc.segment15),
                         XMLELEMENT (
                             "v1:description1",
                             segment_desc (v_coa_id, 'SEGMENT1', cc.segment1)),
                         XMLELEMENT (
                             "v1:description2",
                             segment_desc (v_coa_id, 'SEGMENT2', cc.segment2)),
                         XMLELEMENT (
                             "v1:description3",
                             segment_desc (v_coa_id, 'SEGMENT3', cc.segment3)),
                         XMLELEMENT (
                             "v1:description4",
                             segment_desc (v_coa_id, 'SEGMENT4', cc.segment4)),
                         XMLELEMENT (
                             "v1:description5",
                             segment_desc (v_coa_id, 'SEGMENT5', cc.segment5)),
                         XMLELEMENT (
                             "v1:description6",
                             segment_desc (v_coa_id, 'SEGMENT6', cc.segment6)),
                         XMLELEMENT (
                             "v1:description7",
                             segment_desc (v_coa_id, 'SEGMENT7', cc.segment7)),
                         XMLELEMENT (
                             "v1:description8",
                             segment_desc (v_coa_id, 'SEGMENT8', cc.segment8)),
                         XMLELEMENT (
                             "v1:description9",
                             segment_desc (v_coa_id, 'SEGMENT9', cc.segment9)),
                         XMLELEMENT (
                             "v1:description10",
                             segment_desc (v_coa_id, 'SEGMENT10', cc.segment10)),
                         XMLELEMENT (
                             "v1:description11",
                             segment_desc (v_coa_id, 'SEGMENT11', cc.segment11)),
                         XMLELEMENT (
                             "v1:description12",
                             segment_desc (v_coa_id, 'SEGMENT12', cc.segment12)),
                         XMLELEMENT (
                             "v1:description13",
                             segment_desc (v_coa_id, 'SEGMENT13', cc.segment13)),
                         XMLELEMENT (
                             "v1:description14",
                             segment_desc (v_coa_id, 'SEGMENT14', cc.segment14)),
                         XMLELEMENT (
                             "v1:description15",
                             segment_desc (v_coa_id, 'SEGMENT15', cc.segment15)),
                         XMLELEMENT ("v1:set_of_books_id",
                                     gl_comp.set_of_books_id))
                         XML_DATA_TAG
                FROM apps.gl_code_combinations_kfv CC,
                     XXDO.XXDOGL006_INT GL006,
                     (SELECT fv.flex_value, fv.attribute6 set_of_books_id
                        FROM apps.fnd_id_flex_structures_tl ffs, apps.fnd_id_flex_segments_vl fs, apps.fnd_flex_values fv
                       WHERE     ffs.id_flex_num = V_COA_ID -- Links to gl_ledgers.chart_of_accounts_id
                             AND ffs.id_flex_code = 'GL#'
                             AND ffs.language = USERENV ('LANG')
                             AND ffs.id_flex_num = fs.id_flex_num
                             AND ffs.id_flex_code = fs.id_flex_code
                             AND fs.application_column_name = 'SEGMENT1' -- ex: SEGMENT1, SEGMENT2, etc
                             AND fs.flex_value_set_id = fv.flex_value_set_id
                             AND NVL (fv.attribute12, 'N') = 'Y' -- DFF "Interface to Oracle Retail?"
                                                                ) gl_comp,
                     (SELECT fv.flex_value
                        FROM apps.fnd_id_flex_structures_tl ffs, apps.fnd_id_flex_segments_vl fs, apps.fnd_flex_values fv
                       WHERE     ffs.id_flex_num = V_COA_ID -- Links to gl_ledgers.chart_of_accounts_id
                             AND ffs.id_flex_code = 'GL#'
                             AND ffs.language = USERENV ('LANG')
                             AND ffs.id_flex_num = fs.id_flex_num
                             AND ffs.id_flex_code = fs.id_flex_code
                             --            AND    fs.application_column_name = 'SEGMENT3' -- ex: SEGMENT1, SEGMENT2, etc     Commented by BT Tehcnology Team on 20-jan-2015
                             AND fs.application_column_name = 'SEGMENT6' --Added by BT Tehcnology Team on 20_jan_2015
                             AND fs.flex_value_set_id = fv.flex_value_set_id
                             AND NVL (fv.attribute12, 'N') = 'Y' -- DFF "Interface to Oracle Retail?"
                                                                ) gl_cc
               WHERE     cc.chart_of_accounts_id = V_COA_ID -- Deckers Chart of Accounts Structure (4 segments) shared by all ledgers
                     AND cc.detail_posting_allowed = 'Y'
                     AND cc.summary_flag = 'N'
                     AND cc.enabled_flag = 'Y' -- Unsure if this condition should be included going forward (or include ALL) for integrity purposes..
                     AND cc.segment1 = gl_comp.flex_value -- Company DFF "Interface to Oracle Retail?" -- ('07' ,'14', '17','18','25', '21','31') -- 07 Retail US, 14 Retail UK , 17 = Stelladeck Bejing, 18 = Deckers Japan, 25 Retail Canada, 21 France Retail, 31 Italy Retail
                     --  AND   cc.segment3               = gl_cc.flex_value   -- Account DFF "Interface to Oracle Retail?"     --Commented by BT Tehcnology Team on 20-jan-2015
                     AND cc.segment6 = gl_cc.flex_value ----Added by BT Tehcnology Team on 20_jan_2015
                     --AND   cc.segment3               in ( '41109','54095') -- cc.concatenated_segments    not in ('07.7600.11101.0000','07.7600.11213.0000')
                     AND NVL (cc.ATTRIBUTE1, 'N') = 'N' -- This column updates to 'Y' once processed
                     AND cc.CODE_COMBINATION_ID = GL006.CODE_COMBINATION_ID(+)
                     AND GL006.STATUS_FLAG(+) = 'VE'
                     AND TRUNC (GL006.TRANSMISSION_DATE(+)) >=
                         TRUNC (FND_DATE.canonical_to_date (PV_FROM_DATE))
                     AND TRUNC (GL006.TRANSMISSION_DATE(+)) <=
                         TRUNC (FND_DATE.canonical_to_date (PV_TO_DATE))
            ORDER BY cc.concatenated_segments;

        CURSOR ENABLED_SEGMENTS (v_coa_id IN NUMBER, v_segment IN VARCHAR2)
        IS
              SELECT fv.flex_value, fvd.description
                FROM apps.fnd_id_flex_structures_tl ffs, apps.fnd_id_flex_segments_vl fs, apps.fnd_flex_values fv,
                     apps.fnd_flex_values_tl fvd
               WHERE     ffs.id_flex_num = V_COA_ID -- Links to gl_ledgers.chart_of_accounts_id
                     AND ffs.id_flex_code = 'GL#'
                     AND ffs.language = USERENV ('LANG')
                     AND ffs.id_flex_num = fs.id_flex_num
                     AND ffs.id_flex_code = fs.id_flex_code
                     AND fs.application_column_name = V_SEGMENT -- ex: SEGMENT1, SEGMENT2, etc
                     AND fs.flex_value_set_id = fv.flex_value_set_id
                     AND NVL (fv.attribute12, 'N') = 'Y' -- DFF "Interface to Oracle Retail?"
                     AND fv.flex_value_id = fvd.flex_value_id
                     AND fvd.language = USERENV ('LANG')
            ORDER BY fv.flex_value;


        CURSOR CUR_GLACCPUBLISH IS
            SELECT *
              FROM XXDO.XXDOGL006_INT
             WHERE STATUS_FLAG = 'N';

        CURSOR CUR_ENABLED_SEGMENTS (v_coa_id    IN NUMBER,
                                     v_segment   IN VARCHAR2)
        IS
              SELECT fv.flex_value, fvd.description
                FROM apps.fnd_id_flex_structures_tl ffs, apps.fnd_id_flex_segments_vl fs, apps.fnd_flex_values fv,
                     apps.fnd_flex_values_tl fvd
               WHERE     ffs.id_flex_num = V_COA_ID -- Links to gl_ledgers.chart_of_accounts_id
                     AND ffs.id_flex_code = 'GL#'
                     AND ffs.language = USERENV ('LANG')
                     AND ffs.id_flex_num = fs.id_flex_num
                     AND ffs.id_flex_code = fs.id_flex_code
                     AND fs.application_column_name = V_SEGMENT -- ex: SEGMENT1, SEGMENT2, etc
                     AND fs.flex_value_set_id = fv.flex_value_set_id
                     AND NVL (fv.attribute12, 'N') = 'Y' -- DFF "Interface to Oracle Retail?"
                     AND fv.flex_value_id = fvd.flex_value_id
                     AND fvd.language = USERENV ('LANG')
            ORDER BY fv.flex_value;

        -- Local Variables
        l_set_of_books_id        NUMBER;
        l_ledger_name            APPS.GL_LEDGERS.NAME%TYPE;
        l_chart_of_accounts_id   NUMBER;
        l_structure_name         APPS.FND_ID_FLEX_STRUCTURES_TL.ID_FLEX_STRUCTURE_NAME%TYPE;
        l_count                  NUMBER := 0;
        lv_proceed               VARCHAR2 (1) := 'Y';
        lv_output                VARCHAR2 (32000) := NULL;
    BEGIN
        DELETE FROM XXDO.XXDOGL006_INT;


        -- Derive current GL Set Of Books
        l_set_of_books_id   := FND_PROFILE.VALUE ('GL_SET_OF_BKS_ID');

        -- Derive Chart_Of_Accounts ID for the current - Procedure outputs all combinations for the current chart of accounts structure
        BEGIN
            SELECT l.name ledger_name, l.chart_of_accounts_id, ffs.id_flex_structure_name
              INTO l_ledger_name, l_chart_of_accounts_id, l_structure_name
              FROM apps.gl_ledgers l, apps.fnd_id_flex_structures_tl ffs
             WHERE     l.ledger_id = l_set_of_books_id
                   AND l.chart_of_accounts_id = ffs.id_flex_num
                   AND ffs.id_flex_code = 'GL#'
                   AND ffs.language = USERENV ('LANG');
        EXCEPTION
            WHEN OTHERS
            THEN
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       'Invalid Ledger ID ('
                    || TO_CHAR (l_set_of_books_id)
                    || '). Exiting...');
                PV_RETCODE   := 2;
                RETURN;
        END;


        /* Setting the Retail PROD/DEV Environment based on Oracle Prod / Dev Instances */

        BEGIN
            SELECT DECODE (APPLICATIONS_SYSTEM_NAME -- Start of modification by BT Technology Team on 17-Feb-2016 V2.0
                        --,'PROD',APPS.FND_PROFILE.VALUE('XXDO: RETAIL PROD'),
                   , 'EBSPROD', APPS.FND_PROFILE.VALUE ('XXDO: RETAIL PROD'), -- End of modification by BT Technology Team on 17-Feb-2016 V2.0
                                                                              APPS.FND_PROFILE.VALUE ('XXDO: RETAIL TEST')) FILE_SERVER_NAME
              INTO lv_wsdl_ip
              FROM APPS.FND_PRODUCT_GROUPS;
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'Unable to fetch the File server name');
                pv_retcode   := 2;
        END;


        /*

         LV_FROM_DATE:= FND_DATE.CANONICAL_TO_DATE(PV_FROM_DATE);
         LV_TO_DATE:=FND_DATE.CANONICAL_TO_DATE(PV_TO_DATE);

         */

        /* Initializing the web service variables */

        lv_wsdl_url         :=
               'http://'
            || lv_wsdl_ip
            || '/GLCOAPublishingBean/GLCOAPublishingService?WSDL';
        lv_namespace        :=
            'http://www.oracle.com/retail/igs/integration/services/GLCOAPublishingService/v1';
        lv_service          := 'GLCOAPublishingService';
        lv_port             := 'GLCOAPublishingPort';
        lv_operation        := 'publishGLCOACreateUsingGLCOADesc';
        lv_targetname       :=
               'http://'
            || lv_wsdl_ip
            || '/GLCOAPublishingBean/GLCOAPublishingService';


        lv_output           :=
               'CODE_COMBINATION_ID'
            || CHR (9)
            || 'PRIMARY_ACCOUNT'
            || CHR (9)
            || 'ATTRIBUTE1'
            || CHR (9)
            || 'ATTRIBUTE2'
            || CHR (9)
            || 'ATTRIBUTE3'
            || CHR (9)
            || 'ATTRIBUTE4'
            || CHR (9)
            || 'ATTRIBUTE5'
            || CHR (9)
            || 'ATTRIBUTE6'
            || CHR (9)
            || 'ATTRIBUTE7';

        FND_FILE.PUT_LINE (FND_FILE.OUTPUT, lv_output);


        FOR i
            IN CUR_GL_ACCOUNTS (l_chart_of_accounts_id,
                                PV_FROM_DATE,
                                PV_TO_DATE)
        LOOP
            IF (i.primary_account IS NULL OR i.ATTRIBUTE1 IS NULL OR i.ATTRIBUTE2 IS NULL OR i.ATTRIBUTE3 IS NULL OR i.ATTRIBUTE4 IS NULL)
            THEN
                lv_output    :=
                       i.CODE_COMBINATION_ID
                    || CHR (9)
                    || i.PRIMARY_ACCOUNT
                    || CHR (9)
                    || i.ATTRIBUTE1
                    || CHR (9)
                    || i.ATTRIBUTE2
                    || CHR (9)
                    || i.ATTRIBUTE3
                    || CHR (9)
                    || i.ATTRIBUTE4
                    || CHR (9)
                    || i.ATTRIBUTE5
                    || CHR (9)
                    || i.ATTRIBUTE6
                    || CHR (9)
                    || i.ATTRIBUTE7
                    || 'Error as one of the Mandatory column is NULL and cannot transmit the data';
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, lv_output);
                lv_proceed   := 'N';
            ELSE
                BEGIN
                    /* -- Start as part of  3.0

               INSERT INTO XXDO.XXDOGL006_INT
                    ( CODE_COMBINATION_ID ,
                       PRIMARY_ACCOUNT ,
                       ATTRIBUTE1,
                       ATTRIBUTE2,
                       ATTRIBUTE3,
                       ATTRIBUTE4,
                       ATTRIBUTE5,
                       ATTRIBUTE6,
                       ATTRIBUTE7,
                      XDATA)
                          VALUES
                      (i.CODE_COMBINATION_ID,
                       i.PRIMARY_ACCOUNT,
                       i.ATTRIBUTE1,
                       i.ATTRIBUTE2,
                       i.ATTRIBUTE3,
                       i.ATTRIBUTE4,
                       i.ATTRIBUTE5,
                       i.ATTRIBUTE6,
                       i.ATTRIBUTE7,
                       xmltype.getClobVal(i.XML_DATA_TAG)); */


                    INSERT INTO XXDO.XXDOGL006_INT (CODE_COMBINATION_ID,
                                                    PRIMARY_ACCOUNT,
                                                    SET_OF_BOOKS_ID,
                                                    ATTRIBUTE1,
                                                    ATTRIBUTE2,
                                                    ATTRIBUTE3,
                                                    ATTRIBUTE4,
                                                    ATTRIBUTE5,
                                                    ATTRIBUTE6,
                                                    ATTRIBUTE7,
                                                    ATTRIBUTE8,
                                                    ATTRIBUTE9,
                                                    ATTRIBUTE10,
                                                    ATTRIBUTE11,
                                                    ATTRIBUTE12,
                                                    ATTRIBUTE13,
                                                    ATTRIBUTE14,
                                                    ATTRIBUTE15,
                                                    description1,
                                                    description2,
                                                    description3,
                                                    description4,
                                                    description5,
                                                    description6,
                                                    description7,
                                                    description8,
                                                    description9,
                                                    description10,
                                                    description11,
                                                    description12,
                                                    description13,
                                                    description14,
                                                    description15,
                                                    creation_Date,
                                                    XDATA,
                                                    SEQ_NUMBER)
                             VALUES (i.CODE_COMBINATION_ID,
                                     i.PRIMARY_ACCOUNT,
                                     i.SET_OF_BOOKS_ID,
                                     i.ATTRIBUTE1,
                                     i.ATTRIBUTE2,
                                     i.ATTRIBUTE3,
                                     i.ATTRIBUTE4,
                                     i.ATTRIBUTE5,
                                     i.ATTRIBUTE6,
                                     i.ATTRIBUTE7,
                                     i.ATTRIBUTE8,
                                     i.ATTRIBUTE9,
                                     i.ATTRIBUTE10,
                                     i.ATTRIBUTE11,
                                     i.ATTRIBUTE12,
                                     i.ATTRIBUTE13,
                                     i.ATTRIBUTE14,
                                     i.ATTRIBUTE15,
                                     i.description1,
                                     i.description2,
                                     i.description3,
                                     i.description4,
                                     i.description5,
                                     i.description6,
                                     i.description7,
                                     i.description8,
                                     i.description9,
                                     i.description10,
                                     i.description11,
                                     i.description12,
                                     i.description13,
                                     i.description14,
                                     i.description15,
                                     SYSDATE,
                                     xmltype.getClobVal (i.XML_DATA_TAG),
                                     XXDO.XXDOGL006_INT_S.NEXTVAL);

                    -- End as part of  3.0


                    lv_output   :=
                           i.CODE_COMBINATION_ID
                        || CHR (9)
                        || i.PRIMARY_ACCOUNT
                        || CHR (9)
                        || i.ATTRIBUTE1
                        || CHR (9)
                        || i.ATTRIBUTE2
                        || CHR (9)
                        || i.ATTRIBUTE3
                        || CHR (9)
                        || i.ATTRIBUTE4
                        || CHR (9)
                        || i.ATTRIBUTE5
                        || CHR (9)
                        || i.ATTRIBUTE6
                        || CHR (9)
                        || i.ATTRIBUTE7;

                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT, lv_output);

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                            'Exception occured while loading  data into the staging table');
                END;
            END IF;
        END LOOP;

        IF lv_proceed = 'Y'
        THEN                                                     -- lv_proceed
            FOR J IN CUR_GLACCPUBLISH
            LOOP
                /*  --Commented as part of 3.0

                              lx_xmltype_in:=SYS.XMLTYPE('<publishGLCOACreateUsingGLCOADesc
                                            xmlns="http://www.oracle.com/retail/igs/integration/services/GLCOAPublishingService/v1"
                                            xmlns:v1="http://www.oracle.com/retail/integration/base/bo/GLCOADesc/v1"
                                            xmlns:v11="http://www.oracle.com/retail/integration/custom/bo/ExtOfGLCOADesc/v1"
                                            xmlns:v12="http://www.oracle.com/retail/integration/base/bo/LocOfGLCOADesc/v1"
                                            xmlns:v13="http://www.oracle.com/retail/integration/localization/bo/InGLCOADesc/v1"
                                            xmlns:v14="http://www.oracle.com/retail/integration/custom/bo/EOfInGLCOADesc/v1"
                                            xmlns:v15="http://www.oracle.com/retail/integration/localization/bo/BrGLCOADesc/v1"
                                            xmlns:v16="http://www.oracle.com/retail/integration/custom/bo/EOfBrGLCOADesc/v1">
                                            '||J.XDATA||'</publishGLCOACreateUsingGLCOADesc>');

                         /* Calling the business event here */

                BEGIN
                    --Added as part of 3.0 (Start)
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'RAISING BUSINESS EVENT FOR CHART OF ACCOUNTS   '
                        || SQLERRM);

                    BEGIN
                        apps.wf_event.RAISE (p_event_name => 'oracle.apps.xxdo.retail_gl_code_event', p_event_key => J.CODE_COMBINATION_ID, p_event_data => NULL
                                             , p_parameters => NULL);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            LV_ERRMSG   :=
                                   'Error Message from event call :'
                                || apps.fnd_api.g_ret_sts_error
                                || ' SQL Error '
                                || SQLERRM;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error Message from event call :'
                                || apps.fnd_api.g_ret_sts_error
                                || ' SQL Error '
                                || SQLERRM);

                            UPDATE xxdo.xxdogl006_int
                               SET status_flag = 've', errorcode = lv_errmsg
                             WHERE code_combination_id =
                                   j.code_combination_id;
                    END;

                    COMMIT;                      -- Added as part of 3.0 (End)
                /*  --Commented as part of 3.0
                              lx_xmltype_out :=  XXDO_INVOKE_WEBSERVICE_F( lv_wsdl_url, lv_namespace, lv_targetname, lv_service, lv_port,lv_operation,lx_xmltype_in) ;

                                 IF lx_xmltype_out is not null then

                                 -- FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Response is stored in the staging table  ');

                                   lc_return := xmltype.getClobVal(lx_xmltype_out);

                                   UPDATE XXDO.XXDOGL006_INT
                                   SET RETVAL=LC_RETURN, PROCESSED_FLAG ='Y', STATUS_FLAG='P', TRANSMISSION_DATE=SYSDATE
                                   WHERE CODE_COMBINATION_ID=J.CODE_COMBINATION_ID;

                                   -- Update the Process Flag status in the table.
                                   update gl.gl_code_combinations
                                    set attribute1 ='Y'
                                    where
                                    code_combination_id = J.CODE_COMBINATION_ID;

                                ELSE
                                               FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Response is NULL  ');

                                    lc_return:=NULL;

                                   UPDATE XXDO.XXDOGL006_INT
                                   SET RETVAL=LC_RETURN,  STATUS_FLAG='VE', TRANSMISSION_DATE=SYSDATE
                                   WHERE CODE_COMBINATION_ID=J.CODE_COMBINATION_ID;

                                END IF;

                                COMMIT;

                    */
                --Commented as part of 3.0

                EXCEPTION
                    WHEN OTHERS
                    THEN
                        LV_ERRMSG   := SQLERRM;

                        /* Updating the existing record to validation error and storing the error code */

                        UPDATE XXDO.XXDOGL006_INT
                           SET STATUS_FLAG = 'VE', ERRORCODE = LV_ERRMSG
                         WHERE CODE_COMBINATION_ID = J.CODE_COMBINATION_ID;

                        COMMIT;

                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                               'PROBLEM IN SENDING THE MESSAGE DETAILS STORED IN THE ERRORCODE OF THE STAGING TABLE   '
                            || SQLERRM);
                END;                        /* End calling the webservice   */
            END LOOP;                                    /* For Publish Loc */
        END IF;                                                  -- lv_proceed
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Exception Occured  is    ' || SQLERRM);
    END;
END XXDOGL006_PKG;
/
