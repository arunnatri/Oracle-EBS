--
-- XXD_JP_DIRECT_PO_CONV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:28 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXD_JP_DIRECT_PO_CONV_PKG
AS
    /* ******************************************************************************
       * Program Name : XXD_PO_REQUISITION_CONV_PKG
       * Language     : PL/SQL
       * Description  : This package will load requisition data in to Oracle Purchasing base tables
       *
       * History      :
       *
       * WHO            WHAT              Desc                             WHEN
       * -------------- ---------------------------------------------- ---------------
       * BT Technology Team 1.0                                             01-NOV-2014


    ************************************************************************************** */

    -- +===================================================================+
    -- | Name  : debug_log                                                 |
    -- |                                                                   |
    -- | Description:       This Procedure shall write to the concurrent   |
    -- |                    program log file                               |
    -- +===================================================================+

    PROCEDURE debug_log (p_message IN VARCHAR2)
    IS
    BEGIN
        IF gc_debug_flag = 'Y'
        THEN
            APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG, p_message);
        END IF;
    END debug_log;

    -- +===================================================================+
    -- | Name  : set_application_context                                                 |
    -- |                                                                   |
    -- | Description:       This Procedure shall write to the concurrent   |
    -- |                    program log file                               |
    -- +===================================================================+
    PROCEDURE set_application_context (x_resp_id   OUT NUMBER,
                                       x_app_id    OUT NUMBER)
    IS
        CURSOR get_application_dt_c IS
            SELECT responsibility_id, application_id
              FROM fnd_responsibility_tl
             WHERE     1 = 1
                   AND language = 'US'
                   AND responsibility_name LIKE 'Decker%Order%Super%Macau%'
                   AND ROWNUM = 1;
    BEGIN
        OPEN get_application_dt_c;

        FETCH get_application_dt_c INTO x_resp_id, x_app_id;

        IF get_application_dt_c%NOTFOUND
        THEN
            x_resp_id   := NULL;
            x_app_id    := NULL;
        END IF;

        APPS.fnd_global.APPS_INITIALIZE (gn_user_id, x_resp_id, x_app_id);

        CLOSE get_application_dt_c;
    END set_application_context;

    -- +===================================================================+
    -- | Name  : debug_log                                                 |
    -- |                                                                   |
    -- | Description:       This Procedure shall write to the concurrent   |
    -- |                    program log file                               |
    -- +===================================================================+

    PROCEDURE write_output (p_message IN VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.output, p_message);
    END write_output;


    -- +===================================================================+
    -- | Name  : derive_tgt_ccid                                           |
    -- |                                                                   |
    -- | Description:       This Procedure is used to derive target
    -- |                    system code combination                        |
    -- +===================================================================+
    PROCEDURE derive_tgt_ccid (p_segment1   IN     VARCHAR2,
                               p_segment2   IN     VARCHAR2,
                               p_segment3   IN     VARCHAR2,
                               p_segment4   IN     VARCHAR2,
                               p_org_id     IN     NUMBER,
                               x_tgt_ccid      OUT NUMBER)
    IS
        CURSOR get_gl_code_combination (p_code_combination IN VARCHAR2)
        IS
            SELECT code_combination_id
              FROM gl_code_combinations_kfv
             WHERE concatenated_segments = p_code_combination;

        CURSOR get_coa_id_c IS
            SELECT chart_of_accounts_id
              FROM gl_sets_of_books gsob, hr_operating_units hou
             WHERE     hou.set_of_books_id = gsob.set_of_books_id
                   AND hou.organization_id = p_org_id;

        lc_new_conc_segs   VARCHAR2 (100);
        ln_tgt_ccid        NUMBER;
        ln_coa_id          NUMBER;
    BEGIN
        ln_tgt_ccid       := NULL;
        gc_code_pointer   :=
               'Deriving New Accounts For old Accounts : '
            || p_segment1
            || '.'
            || p_segment2
            || '.'
            || p_segment3
            || '.'
            || p_segment4;
        debug_log (gc_code_pointer);
        lc_new_conc_segs   :=
            XXD_COMMON_UTILS.get_gl_code_combination (p_segment1, p_segment2, p_segment3
                                                      , p_segment4);

        gc_code_pointer   :=
            'Target mapped New Accounts  : ' || lc_new_conc_segs;
        debug_log (gc_code_pointer);

        OPEN get_gl_code_combination (lc_new_conc_segs);

        FETCH get_gl_code_combination INTO ln_tgt_ccid;

        IF get_gl_code_combination%NOTFOUND
        THEN
            ln_tgt_ccid   := NULL;
        END IF;

        CLOSE get_gl_code_combination;

        IF ln_tgt_ccid IS NULL
        THEN
            OPEN get_coa_id_c;

            FETCH get_coa_id_c INTO ln_coa_id;

            CLOSE get_coa_id_c;

            gc_code_pointer   := 'Calling Fnd_Flex_Ext.get_ccid ';
            debug_log (gc_code_pointer);

            BEGIN
                ln_tgt_ccid   :=
                    Fnd_Flex_Ext.get_ccid ('SQLGL', 'GL#', ln_coa_id,
                                           NULL, lc_new_conc_segs);

                IF ln_tgt_ccid IS NULL OR ln_tgt_ccid = 0
                THEN
                    ln_tgt_ccid   := NULL;

                    gc_code_pointer   :=
                           'Error in Fnd_Flex_Ext.get_ccid : '
                        || lc_new_conc_segs;
                    debug_log (gc_code_pointer);
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_tgt_ccid   := NULL;
            END;
        END IF;

        x_tgt_ccid        := ln_tgt_ccid;
    END derive_tgt_ccid;

    /* **************************************************************************************************
   Function  Name: get_agent_name
   Description: This function counts the total number of records in staging table for a particular status.
   Parameters:
   Name                     Type          Description
   ==============           ======       =============================================
   p_table_name             IN           Staging table name .
   p_status                 IN           Record status in stage table.
   p_request_id             IN           Request id for current set of records.
   ************************************************************************************************** */

    FUNCTION get_agent_details (p_agent_name IN VARCHAR2)
        RETURN NUMBER
    IS
        CURSOR get_agent_id_c IS
            SELECT person_id preparer_id
              FROM per_people_f ppf, po_agents pa
             WHERE     full_name = p_agent_name
                   AND pa.agent_id = ppf.person_id
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (effective_start_date,
                                                        SYSDATE))
                                           AND TRUNC (
                                                   NVL (effective_end_date,
                                                        SYSDATE))
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (start_date_active,
                                                        SYSDATE))
                                           AND TRUNC (
                                                   NVL (end_date_active,
                                                        SYSDATE));

        ln_agent_id   NUMBER := NULL;
    BEGIN
        OPEN get_agent_id_c;

        FETCH get_agent_id_c INTO ln_agent_id;

        IF get_agent_id_c%NOTFOUND
        THEN
            ln_agent_id   := NULL;
        END IF;

        CLOSE get_agent_id_c;

        IF ln_agent_id IS NOT NULL
        THEN
            RETURN ln_agent_id;
        ELSE
            RETURN (-1);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN (-1);
    END get_agent_details;



    PROCEDURE get_internal_req_extract_prc (x_retcode   OUT NUMBER,
                                            x_errbuf    OUT VARCHAR2)
    IS
        CURSOR get_internale_req_dt IS
            SELECT * FROM XXD_CONV.XXD_1206_PO_JP_REQ_CONV_STG_T--WHERE requisition_number = '60931'
                                                                ;


        TYPE tbl_requisition_t IS TABLE OF get_internale_req_dt%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_requisition_tbl   tbl_requisition_t;
    BEGIN
        gc_code_pointer   :=
            'Deleting data from  Staging table XXD_CONV.XXD_JP_DIRECT_PO_CONV_STG_T';

        --Deleting data from  Header and line staging table

        debug_log (gc_code_pointer);

        EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_JP_DIRECT_PO_CONV_STG_T';

        gc_code_pointer   :=
            'Inserting into XXD_CONV.XXD_JP_DIRECT_PO_CONV_STG_T  staging table';
        debug_log (gc_code_pointer);

        OPEN get_internale_req_dt;

        LOOP
            FETCH get_internale_req_dt
                BULK COLLECT INTO lt_requisition_tbl
                LIMIT gn_limit;

            IF lt_requisition_tbl.COUNT > 0
            THEN
                BEGIN
                    FORALL i IN 1 .. lt_requisition_tbl.COUNT SAVE EXCEPTIONS
                        INSERT INTO XXD_CONV.XXD_JP_DIRECT_PO_CONV_STG_T (
                                        RECORD_ID,
                                        AUTHORIZATION_STATUS,
                                        CATEGORY_ID,
                                        requisition_type,
                                        OLD_REQUISITION_HEADER_ID,
                                        REQUISITION_LINE_ID,
                                        --OLD_REQUISITION_LINE_ID,
                                        DISTRIBUTION_ID,
                                        CATEGORY_NAME,
                                        CHARGE_ACCOUNT_ID,
                                        CONCATENATED_SEGMENTS,
                                        DELIVER_TO_LOCATION_ID,
                                        DESTINATION_ORGANIZATION_ID,
                                        SOURCE_ORGANIZATION_ID,
                                        DESTINATION_TYPE_CODE,
                                        INTERFACE_SOURCE_CODE,
                                        ITEM_NUMBER,
                                        ITEM_DESCRIPTION,
                                        ITEM_ID,
                                        LINE_TYPE,
                                        LINE_TYPE_ID,
                                        LOCATION_CODE,
                                        NEED_BY_DATE,
                                        promised_date,
                                        OPERATING_UNIT,
                                        destination_organization_name,
                                        source_organization_name,
                                        ORG_ID,
                                        PREPARER,
                                        PREPARER_ID,
                                        QUANTITY,
                                        QUANTITY_RECEIVE,
                                        AGENT_NAME,
                                        REQUESTOR,
                                        REQUISITION_NUMBER,
                                        SEGMENT1,
                                        SEGMENT2,
                                        SEGMENT3,
                                        SEGMENT4,
                                        SOURCE_TYPE_CODE,
                                        TO_PERSON_ID,
                                        UNIT_MEAS_LOOKUP_CODE,
                                        UNIT_PRICE,
                                        line_num,
                                        PO_LINE_NUM,
                                        SHIPMENT_NUM,       --ADDED ON 19THMAY
                                        vendor_name,
                                        --vendor_id,
                                        vendor_site_code,
                                        ORDER_NUMBER,
                                        order_type,
                                        conversion_type_code,
                                        --vendor_site_id,
                                        REQ_HEADER_ATTRIBUTE_CATEGORY,
                                        REQ_HEADER_ATTRIBUTE1,
                                        REQ_HEADER_ATTRIBUTE2,
                                        REQ_HEADER_ATTRIBUTE3,
                                        REQ_HEADER_ATTRIBUTE4,
                                        REQ_HEADER_ATTRIBUTE5,
                                        REQ_HEADER_ATTRIBUTE6,
                                        REQ_HEADER_ATTRIBUTE7,
                                        REQ_HEADER_ATTRIBUTE8,
                                        REQ_HEADER_ATTRIBUTE9,
                                        REQ_HEADER_ATTRIBUTE10,
                                        REQ_HEADER_ATTRIBUTE11,
                                        REQ_HEADER_ATTRIBUTE12,
                                        REQ_HEADER_ATTRIBUTE13,
                                        REQ_HEADER_ATTRIBUTE14,
                                        REQ_HEADER_ATTRIBUTE15,
                                        REQ_LINE_ATTRIBUTE_CATEGORY,
                                        REQ_LINE_ATTRIBUTE1,
                                        REQ_LINE_ATTRIBUTE2,
                                        REQ_LINE_ATTRIBUTE3,
                                        REQ_LINE_ATTRIBUTE4,
                                        REQ_LINE_ATTRIBUTE5,
                                        REQ_LINE_ATTRIBUTE6,
                                        REQ_LINE_ATTRIBUTE7,
                                        REQ_LINE_ATTRIBUTE8,
                                        REQ_LINE_ATTRIBUTE9,
                                        REQ_LINE_ATTRIBUTE10,
                                        REQ_LINE_ATTRIBUTE11,
                                        REQ_LINE_ATTRIBUTE12,
                                        REQ_LINE_ATTRIBUTE13,
                                        REQ_LINE_ATTRIBUTE14,
                                        REQ_LINE_ATTRIBUTE15,
                                        REQ_DIST_ATTRIBUTE_CATEGORY,
                                        REQ_DIST_ATTRIBUTE1,
                                        REQ_DIST_ATTRIBUTE2,
                                        REQ_DIST_ATTRIBUTE3,
                                        REQ_DIST_ATTRIBUTE4,
                                        REQ_DIST_ATTRIBUTE5,
                                        REQ_DIST_ATTRIBUTE6,
                                        REQ_DIST_ATTRIBUTE7,
                                        REQ_DIST_ATTRIBUTE8,
                                        REQ_DIST_ATTRIBUTE9,
                                        REQ_DIST_ATTRIBUTE10,
                                        REQ_DIST_ATTRIBUTE11,
                                        REQ_DIST_ATTRIBUTE12,
                                        REQ_DIST_ATTRIBUTE13,
                                        REQ_DIST_ATTRIBUTE14,
                                        REQ_DIST_ATTRIBUTE15,
                                        header_attribute_category,
                                        header_attribute1,
                                        header_attribute2,
                                        header_attribute3,
                                        header_attribute4,
                                        header_attribute5,
                                        header_attribute6,
                                        header_attribute7,
                                        header_attribute8,
                                        header_attribute9,
                                        header_attribute10,
                                        header_attribute11,
                                        header_attribute12,
                                        header_attribute13,
                                        header_attribute14,
                                        header_attribute15,
                                        line_attribute_category,
                                        line_attribute1,
                                        line_attribute2,
                                        line_attribute3,
                                        line_attribute4,
                                        line_attribute5,
                                        line_attribute6,
                                        line_attribute7,
                                        line_attribute8,
                                        line_attribute9,
                                        line_attribute10,
                                        line_attribute11,
                                        line_attribute12,
                                        line_attribute13,
                                        line_attribute14,
                                        line_attribute15,
                                        SHIPMENT_ATTRIBUTE_CATEGORY,
                                        SHIPMENT_ATTRIBUTE1,
                                        SHIPMENT_ATTRIBUTE2,
                                        SHIPMENT_ATTRIBUTE3,
                                        SHIPMENT_ATTRIBUTE4,
                                        SHIPMENT_ATTRIBUTE5,
                                        SHIPMENT_ATTRIBUTE6,
                                        SHIPMENT_ATTRIBUTE7,
                                        SHIPMENT_ATTRIBUTE8,
                                        SHIPMENT_ATTRIBUTE9,
                                        SHIPMENT_ATTRIBUTE10,
                                        SHIPMENT_ATTRIBUTE11,
                                        SHIPMENT_ATTRIBUTE12,
                                        SHIPMENT_ATTRIBUTE13,
                                        SHIPMENT_ATTRIBUTE14,
                                        SHIPMENT_ATTRIBUTE15,
                                        dist_attribute_category,
                                        dist_attribute1,
                                        dist_attribute2,
                                        dist_attribute3,
                                        dist_attribute4,
                                        dist_attribute5,
                                        dist_attribute6,
                                        dist_attribute7,
                                        dist_attribute8,
                                        dist_attribute9,
                                        dist_attribute10,
                                        dist_attribute11,
                                        dist_attribute12,
                                        dist_attribute13,
                                        dist_attribute14,
                                        dist_attribute15,
                                        --Added on 01-JUL-2015
                                        EDI_PROCESSED_FLAG,
                                        EDI_PROCESSED_STATUS,
                                        --Added on 01-JUL-2015
                                        DESTINATION_SUBINVENTORY,
                                        DIST_QUANTITY,
                                        record_status,
                                        LAST_UPDATE_DATE,
                                        LAST_UPDATED_BY,
                                        LAST_UPDATED_LOGIN,
                                        CREATION_DATE,
                                        CREATED_BY,
                                        request_id,
                                        po_number,
                                        purchase_req_number,
                                        po_header_id,
                                        po_line_id,
                                        IR_creation_date,
                                        ISO_creation_date,
                                        PR_creation_date,
                                        PO_creation_date)
                                 VALUES (
                                            XXD_JP_DIRECT_PO_RECORD_STG_S.NEXTVAL,
                                            lt_requisition_tbl (i).AUTHORIZATION_STATUS,
                                            lt_requisition_tbl (i).CATEGORY_ID,
                                            lt_requisition_tbl (i).requisition_type,
                                            lt_requisition_tbl (i).REQUISITION_HEADER_ID,
                                            lt_requisition_tbl (i).REQUISITION_LINE_ID,
                                            lt_requisition_tbl (i).PO_DISTRIBUTION_ID,
                                            lt_requisition_tbl (i).CATEGORY_NAME,
                                            lt_requisition_tbl (i).CHARGE_ACCOUNT_ID,
                                            lt_requisition_tbl (i).CONCATENATED_SEGMENTS,
                                            lt_requisition_tbl (i).DELIVER_TO_LOCATION_ID,
                                            lt_requisition_tbl (i).DESTINATION_ORGANIZATION_ID,
                                            lt_requisition_tbl (i).SOURCE_ORGANIZATION_ID,
                                            lt_requisition_tbl (i).DESTINATION_TYPE_CODE,
                                            lt_requisition_tbl (i).INTERFACE_SOURCE_CODE,
                                            lt_requisition_tbl (i).ITEM_NUMBER,
                                            lt_requisition_tbl (i).ITEM_DESCRIPTION,
                                            lt_requisition_tbl (i).ITEM_ID,
                                            lt_requisition_tbl (i).LINE_TYPE,
                                            lt_requisition_tbl (i).LINE_TYPE_ID,
                                            lt_requisition_tbl (i).LOCATION_CODE,
                                            lt_requisition_tbl (i).NEED_BY_DATE,
                                            lt_requisition_tbl (i).promised_date,
                                            lt_requisition_tbl (i).OPERATING_UNIT,
                                            lt_requisition_tbl (i).destination_organization_name,
                                            lt_requisition_tbl (i).source_organization_name,
                                            lt_requisition_tbl (i).ORG_ID,
                                            lt_requisition_tbl (i).PREPARER,
                                            lt_requisition_tbl (i).PREPARER_ID,
                                            lt_requisition_tbl (i).QUANTITY,
                                            lt_requisition_tbl (i).QUANTITY_RECEIVE,
                                            lt_requisition_tbl (i).AGENT_NAME,
                                            lt_requisition_tbl (i).REQUESTOR,
                                            lt_requisition_tbl (i).REQUISITION_NUMBER,
                                            lt_requisition_tbl (i).SEGMENT1,
                                            lt_requisition_tbl (i).SEGMENT2,
                                            lt_requisition_tbl (i).SEGMENT3,
                                            lt_requisition_tbl (i).SEGMENT4,
                                            lt_requisition_tbl (i).SOURCE_TYPE_CODE,
                                            lt_requisition_tbl (i).TO_PERSON_ID,
                                            lt_requisition_tbl (i).UNIT_MEAS_LOOKUP_CODE,
                                            lt_requisition_tbl (i).UNIT_PRICE,
                                            lt_requisition_tbl (i).req_line_num,
                                            lt_requisition_tbl (i).PO_line_num,
                                            lt_requisition_tbl (i).SHIPMENT_NUM, --ADDED ON 19THMAY
                                            lt_requisition_tbl (i).vendor_name,
                                            --lt_requisition_tbl (i).vendor_id,
                                            lt_requisition_tbl (i).vendor_site_code,
                                            lt_requisition_tbl (i).ORDER_NUMBER,
                                            lt_requisition_tbl (i).order_type,
                                            lt_requisition_tbl (i).conversion_type_code,
                                            --lt_requisition_tbl (i).vendor_site_id,
                                            lt_requisition_tbl (i).REQ_HEADER_ATTRIBUTE_CATEGORY,
                                            lt_requisition_tbl (i).REQ_HEADER_ATTRIBUTE1,
                                            lt_requisition_tbl (i).REQ_HEADER_ATTRIBUTE2,
                                            lt_requisition_tbl (i).REQ_HEADER_ATTRIBUTE3,
                                            lt_requisition_tbl (i).REQ_HEADER_ATTRIBUTE4,
                                            lt_requisition_tbl (i).REQ_HEADER_ATTRIBUTE5,
                                            lt_requisition_tbl (i).REQ_HEADER_ATTRIBUTE6,
                                            lt_requisition_tbl (i).REQ_HEADER_ATTRIBUTE7,
                                            lt_requisition_tbl (i).REQ_HEADER_ATTRIBUTE8,
                                            lt_requisition_tbl (i).REQ_HEADER_ATTRIBUTE9,
                                            lt_requisition_tbl (i).REQ_HEADER_ATTRIBUTE10,
                                            lt_requisition_tbl (i).REQ_HEADER_ATTRIBUTE11,
                                            lt_requisition_tbl (i).REQ_HEADER_ATTRIBUTE12,
                                            lt_requisition_tbl (i).REQ_HEADER_ATTRIBUTE13,
                                            lt_requisition_tbl (i).REQ_HEADER_ATTRIBUTE14,
                                            lt_requisition_tbl (i).REQ_HEADER_ATTRIBUTE15,
                                            lt_requisition_tbl (i).REQ_LINE_ATTRIBUTE_CATEGORY,
                                            lt_requisition_tbl (i).REQ_LINE_ATTRIBUTE1,
                                            lt_requisition_tbl (i).REQ_LINE_ATTRIBUTE2,
                                            lt_requisition_tbl (i).REQ_LINE_ATTRIBUTE3,
                                            lt_requisition_tbl (i).REQ_LINE_ATTRIBUTE4,
                                            lt_requisition_tbl (i).REQ_LINE_ATTRIBUTE5,
                                            lt_requisition_tbl (i).REQ_LINE_ATTRIBUTE6,
                                            lt_requisition_tbl (i).REQ_LINE_ATTRIBUTE7,
                                            lt_requisition_tbl (i).REQ_LINE_ATTRIBUTE8,
                                            lt_requisition_tbl (i).REQ_LINE_ATTRIBUTE9,
                                            lt_requisition_tbl (i).REQ_LINE_ATTRIBUTE10,
                                            lt_requisition_tbl (i).REQ_LINE_ATTRIBUTE11,
                                            lt_requisition_tbl (i).REQ_LINE_ATTRIBUTE12,
                                            lt_requisition_tbl (i).REQ_LINE_ATTRIBUTE13,
                                            lt_requisition_tbl (i).REQ_LINE_ATTRIBUTE14,
                                            lt_requisition_tbl (i).REQ_LINE_ATTRIBUTE15,
                                            lt_requisition_tbl (i).REQ_DIST_ATTRIBUTE_CATEGORY,
                                            lt_requisition_tbl (i).REQ_DIST_ATTRIBUTE1,
                                            lt_requisition_tbl (i).REQ_DIST_ATTRIBUTE2,
                                            lt_requisition_tbl (i).REQ_DIST_ATTRIBUTE3,
                                            lt_requisition_tbl (i).REQ_DIST_ATTRIBUTE4,
                                            lt_requisition_tbl (i).REQ_DIST_ATTRIBUTE5,
                                            lt_requisition_tbl (i).REQ_DIST_ATTRIBUTE6,
                                            lt_requisition_tbl (i).REQ_DIST_ATTRIBUTE7,
                                            lt_requisition_tbl (i).REQ_DIST_ATTRIBUTE8,
                                            lt_requisition_tbl (i).REQ_DIST_ATTRIBUTE9,
                                            lt_requisition_tbl (i).REQ_DIST_ATTRIBUTE10,
                                            lt_requisition_tbl (i).REQ_DIST_ATTRIBUTE11,
                                            lt_requisition_tbl (i).REQ_DIST_ATTRIBUTE12,
                                            lt_requisition_tbl (i).REQ_DIST_ATTRIBUTE13,
                                            lt_requisition_tbl (i).REQ_DIST_ATTRIBUTE14,
                                            lt_requisition_tbl (i).REQ_DIST_ATTRIBUTE15,
                                            lt_requisition_tbl (i).PO_ATTRIBUTE_CATEGORY,
                                            lt_requisition_tbl (i).po_header_attribute1,
                                            lt_requisition_tbl (i).po_header_attribute2,
                                            lt_requisition_tbl (i).po_header_attribute3,
                                            lt_requisition_tbl (i).po_header_attribute4,
                                            lt_requisition_tbl (i).po_header_attribute5,
                                            lt_requisition_tbl (i).po_header_attribute6,
                                            lt_requisition_tbl (i).po_header_attribute7,
                                            lt_requisition_tbl (i).po_header_attribute8,
                                            lt_requisition_tbl (i).po_header_attribute9,
                                            lt_requisition_tbl (i).po_header_attribute10,
                                            lt_requisition_tbl (i).po_header_attribute11,
                                            lt_requisition_tbl (i).po_header_attribute12,
                                            lt_requisition_tbl (i).po_header_attribute13,
                                            lt_requisition_tbl (i).po_header_attribute14,
                                            lt_requisition_tbl (i).po_header_attribute15,
                                            lt_requisition_tbl (i).line_attribute_category,
                                            lt_requisition_tbl (i).po_line_attribute1,
                                            lt_requisition_tbl (i).po_line_attribute2,
                                            lt_requisition_tbl (i).po_line_attribute3,
                                            lt_requisition_tbl (i).po_line_attribute4,
                                            lt_requisition_tbl (i).po_line_attribute5,
                                            lt_requisition_tbl (i).po_line_attribute6,
                                            lt_requisition_tbl (i).po_line_attribute7,
                                            lt_requisition_tbl (i).po_line_attribute8,
                                            lt_requisition_tbl (i).po_line_attribute9,
                                            lt_requisition_tbl (i).po_line_attribute10,
                                            lt_requisition_tbl (i).po_line_attribute11,
                                            lt_requisition_tbl (i).po_line_attribute12,
                                            lt_requisition_tbl (i).po_line_attribute13,
                                            lt_requisition_tbl (i).po_line_attribute14,
                                            lt_requisition_tbl (i).po_line_attribute15,
                                            -- lt_requisition_tbl (i).REQUISITION_LINE_ID,
                                            lt_requisition_tbl (i).SHIPMENT_ATTRIBUTE_category,
                                            lt_requisition_tbl (i).po_SHIPMENT_ATTRIBUTE1,
                                            lt_requisition_tbl (i).po_SHIPMENT_ATTRIBUTE2,
                                            lt_requisition_tbl (i).po_SHIPMENT_ATTRIBUTE3,
                                            lt_requisition_tbl (i).po_SHIPMENT_ATTRIBUTE4,
                                            lt_requisition_tbl (i).po_SHIPMENT_ATTRIBUTE5,
                                            lt_requisition_tbl (i).po_SHIPMENT_ATTRIBUTE6,
                                            lt_requisition_tbl (i).po_SHIPMENT_ATTRIBUTE7,
                                            lt_requisition_tbl (i).po_SHIPMENT_ATTRIBUTE8,
                                            lt_requisition_tbl (i).po_SHIPMENT_ATTRIBUTE9,
                                            lt_requisition_tbl (i).po_SHIPMENT_ATTRIBUTE10,
                                            lt_requisition_tbl (i).po_SHIPMENT_ATTRIBUTE11,
                                            lt_requisition_tbl (i).po_SHIPMENT_ATTRIBUTE12,
                                            lt_requisition_tbl (i).po_SHIPMENT_ATTRIBUTE13,
                                            lt_requisition_tbl (i).po_SHIPMENT_ATTRIBUTE14,
                                            lt_requisition_tbl (i).po_SHIPMENT_ATTRIBUTE15,
                                            lt_requisition_tbl (i).po_dist_attribute_category,
                                            lt_requisition_tbl (i).po_dist_attribute1,
                                            lt_requisition_tbl (i).po_dist_attribute2,
                                            lt_requisition_tbl (i).po_dist_attribute3,
                                            lt_requisition_tbl (i).po_dist_attribute4,
                                            lt_requisition_tbl (i).po_dist_attribute5,
                                            lt_requisition_tbl (i).po_dist_attribute6,
                                            lt_requisition_tbl (i).po_dist_attribute7,
                                            lt_requisition_tbl (i).po_dist_attribute8,
                                            lt_requisition_tbl (i).po_dist_attribute9,
                                            lt_requisition_tbl (i).po_dist_attribute10,
                                            lt_requisition_tbl (i).po_dist_attribute11,
                                            lt_requisition_tbl (i).po_dist_attribute12,
                                            lt_requisition_tbl (i).po_dist_attribute13,
                                            lt_requisition_tbl (i).po_dist_attribute14,
                                            lt_requisition_tbl (i).po_dist_attribute15,
                                            --Added on 01-JUL-2015
                                            lt_requisition_tbl (i).EDI_PROCESSED_FLAG,
                                            lt_requisition_tbl (i).EDI_PROCESSED_STATUS,
                                            --Added on 01-JUL-2015
                                            lt_requisition_tbl (i).DESTINATION_SUBINVENTORY, --Modifed on 11-MAY-2015
                                            lt_requisition_tbl (i).DIST_QUANTITY,
                                            'N',
                                            gd_sysdate,
                                            gn_user_id,
                                            gn_login_id,
                                            gd_sysdate,
                                            gn_user_id,
                                            gn_req_id,
                                            lt_requisition_tbl (i).po_number,
                                            lt_requisition_tbl (i).purchase_req_number,
                                            lt_requisition_tbl (i).po_header_id,
                                            lt_requisition_tbl (i).po_line_id,
                                            lt_requisition_tbl (i).IR_creation_date,
                                            lt_requisition_tbl (i).ISO_creation_date,
                                            lt_requisition_tbl (i).PR_creation_date,
                                            lt_requisition_tbl (i).PO_creation_date);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        IF SQLCODE = -24381
                        THEN
                            gc_code_pointer   :=
                                'Exception while extracing req data';

                            FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                            LOOP
                                XXD_common_utils.record_error (
                                    'PORQE',
                                    gn_org_id,
                                    'Deckers PO Requisition Conversion',
                                       'Error code '
                                    || SQLERRM (
                                           -(SQL%BULK_EXCEPTIONS (indx).ERROR_CODE)),
                                    DBMS_UTILITY.format_error_backtrace,
                                    gn_user_id,
                                    gn_req_id,
                                    'Code pointer : ' || gc_code_pointer,
                                    'XXD_JP_DIRECT_PO_CONV_STG_T');
                            END LOOP;
                        ELSE
                            XXD_common_utils.record_error (
                                'PORQE',
                                gn_org_id,
                                'Deckers JP PO Requisition Conversion',
                                'Error in get_internal_req_extract_prc procedure',
                                DBMS_UTILITY.format_error_backtrace,
                                gn_user_id,
                                gn_req_id,
                                'Code pointer : ' || gc_code_pointer,
                                'XXD_JP_DIRECT_PO_CONV_STG_T');
                        END IF;
                END;
            ELSE
                EXIT;
            END IF;

            lt_requisition_tbl.delete;

            COMMIT;
        END LOOP;

        gc_code_pointer   := 'Inserted successfully';
        debug_log (gc_code_pointer);
    END get_internal_req_extract_prc;


    /* **************************************************************************************************
     Function  Name: validate_requisition_prc
     Description: This procedure will validate the requisition data
     Parameters:
     Name                     Type          Description
     ==============           ======       =============================================
     p_table_name             IN           Staging table name .
     p_status                 IN           Record status in stage table.
     p_request_id             IN           Request id for current set of records.
     ************************************************************************************************** */


    PROCEDURE validate_requisition_prc (x_retcode   OUT NUMBER,
                                        x_errbuff   OUT VARCHAR2)
    IS
        -- get all requisition which are in status New or Error
        CURSOR get_requisiton_val_c IS
            SELECT *
              FROM XXD_CONV.XXD_JP_DIRECT_PO_CONV_STG_T
             WHERE record_status IN
                       (gc_new_record, gc_error_record, gc_valid_record);


        CURSOR get_vendor_id_c (p_vendor_name VARCHAR2)
        IS
            SELECT vendor_id
              FROM ap_suppliers
             WHERE vendor_name = p_vendor_name;



        CURSOR get_vendor_site_id_c (p_vendor_id          NUMBER,
                                     p_vendor_site_code   VARCHAR2)
        IS
            SELECT vendor_site_id
              FROM ap_supplier_sites_all
             WHERE     vendor_id = p_vendor_id
                   AND vendor_site_code = p_vendor_site_code;

        CURSOR get_ir_src_organization_c IS
            SELECT organization_id
              FROM org_organization_definitions
             WHERE organization_code LIKE 'MC1';

        CURSOR get_ir_dest_organization_c IS
            SELECT organization_id
              FROM org_organization_definitions
             WHERE organization_code LIKE 'JP5';

        CURSOR get_line_type_id_c (p_line_type VARCHAR2)
        IS
            SELECT line_type_id
              FROM po_line_types
             WHERE line_type = p_line_type;


        CURSOR get_val_item_c (p_item VARCHAR2)
        IS
            SELECT inventory_item_id, DESCRIPTION
              FROM mtl_system_items_b
             WHERE     segment1 = p_item
                   AND INVENTORY_ITEM_STATUS_CODE = 'Active';

        CURSOR get_ir_org_id IS
            SELECT organization_id
              FROM hr_operating_units
             WHERE name LIKE 'Deckers Japan OU';

        CURSOR get_location_id_c (p_organization_id NUMBER)
        IS
            SELECT location_id
              FROM hr_locations_all
             WHERE 1 = 1 AND inventory_organization_id = p_organization_id;



        ln_val_fail_cnt              NUMBER := 0;
        ln_success_cnt               NUMBER := 0;
        lc_err_msg                   VARCHAR2 (4000);
        lc_err_flag                  VARCHAR2 (1);
        ln_vendor_site_id            NUMBER;
        ln_vendor_id                 NUMBER;
        ln_ir_src_organization_id    NUMBER;
        ln_ir_dest_organization_id   NUMBER;
        ln_line_type_id              NUMBER;
        ln_inv_item_id               NUMBER;
        lc_inv_item_desc             VARCHAR2 (500);
        ln_agent_id                  NUMBER;
        ln_ir_org_id                 NUMBER;
        ln_tgt_charge_acct_id        NUMBER;
        ln_ir_location_id            NUMBER;
    BEGIN
        FOR rec_requisiton_val_c IN get_requisiton_val_c
        LOOP
            lc_err_flag                  := gc_no_flag;
            lc_err_msg                   := NULL;
            ln_vendor_site_id            := NULL;
            ln_vendor_id                 := NULL;
            ln_ir_src_organization_id    := NULL;
            ln_ir_dest_organization_id   := NULL;
            ln_inv_item_id               := NULL;
            lc_inv_item_desc             := NULL;
            ln_line_type_id              := NULL;
            ln_agent_id                  := NULL;
            ln_ir_org_id                 := NULL;
            ln_tgt_charge_acct_id        := NULL;
            ln_ir_location_id            := NULL;

            gc_code_pointer              := 'Validate Vendor name';

            --  debug_log(gc_code_pointer);

            IF rec_requisiton_val_c.vendor_name IS NOT NULL
            THEN
                OPEN get_vendor_id_c (rec_requisiton_val_c.vendor_name);

                FETCH get_vendor_id_c INTO ln_vendor_id;

                IF get_vendor_id_c%NOTFOUND
                THEN
                    ln_vendor_id   := NULL;
                    lc_err_msg     := lc_err_msg || '/ Vendor Invalid';
                    lc_err_flag    := gc_yes_flag;
                END IF;

                CLOSE get_vendor_id_c;



                IF ln_vendor_id IS NOT NULL
                THEN
                    gc_code_pointer   := 'Validate Vendor Site Code';

                    --   debug_log(gc_code_pointer);

                    OPEN get_vendor_site_id_c (
                        ln_vendor_id,
                        rec_requisiton_val_c.vendor_site_code);

                    FETCH get_vendor_site_id_c INTO ln_vendor_site_id;

                    IF get_vendor_site_id_c%NOTFOUND
                    THEN
                        ln_vendor_site_id   := NULL;
                        lc_err_msg          :=
                            lc_err_msg || '/ Vendor Site Invalid';
                        lc_err_flag         := gc_yes_flag;
                    END IF;

                    CLOSE get_vendor_site_id_c;
                END IF;
            END IF;

            gc_code_pointer              := 'Deriving source org';
            debug_log (gc_code_pointer);

            OPEN get_ir_src_organization_c;

            FETCH get_ir_src_organization_c INTO ln_ir_src_organization_id;

            gc_code_pointer              :=
                'source org :' || ln_ir_src_organization_id;
            debug_log (gc_code_pointer);

            IF get_ir_src_organization_c%NOTFOUND
            THEN
                ln_ir_src_organization_id   := NULL;
                lc_err_msg                  :=
                    lc_err_msg || '/ Source Organization MC1 not exists';
                lc_err_flag                 := gc_yes_flag;
            END IF;

            CLOSE get_ir_src_organization_c;

            OPEN get_ir_dest_organization_c;

            FETCH get_ir_dest_organization_c INTO ln_ir_dest_organization_id;

            IF get_ir_dest_organization_c%NOTFOUND
            THEN
                ln_ir_dest_organization_id   := NULL;
                lc_err_msg                   :=
                    lc_err_msg || '/ Destination Organization JP5 not exists';
                lc_err_flag                  := gc_yes_flag;
            END IF;

            CLOSE get_ir_dest_organization_c;

            OPEN get_line_type_id_c (rec_requisiton_val_c.line_type);

            FETCH get_line_type_id_c INTO ln_line_type_id;

            IF get_line_type_id_c%NOTFOUND
            THEN
                ln_line_type_id   := NULL;
                lc_err_msg        := lc_err_msg || '/ Line Type Invalid';
                lc_err_flag       := gc_yes_flag;
            END IF;

            CLOSE get_line_type_id_c;


            OPEN get_val_item_c (rec_requisiton_val_c.item_number);

            FETCH get_val_item_c INTO ln_inv_item_id, lc_inv_item_desc;

            IF get_val_item_c%NOTFOUND
            THEN
                ln_inv_item_id   := NULL;
                lc_err_msg       := lc_err_msg || '/ Invalid Item Segments';
                lc_err_flag      := gc_yes_flag;
            END IF;

            CLOSE get_val_item_c;


            ln_agent_id                  :=
                get_agent_details (rec_requisiton_val_c.agent_name);

            IF ln_agent_id = -1
            THEN
                ln_agent_id   := get_agent_details ('Stewart, Celene');

                IF ln_agent_id = -1
                THEN
                    lc_err_msg    := lc_err_msg || '/ Invalid Buyer';
                    lc_err_flag   := gc_yes_flag;
                END IF;
            END IF;

            OPEN get_ir_org_id;

            FETCH get_ir_org_id INTO ln_ir_org_id;

            IF get_ir_org_id%NOTFOUND
            THEN
                lc_err_msg    :=
                    lc_err_msg || '/ Invalid OU: Deckers Japan OU';
                lc_err_flag   := gc_yes_flag;
            END IF;

            CLOSE get_ir_org_id;

            derive_tgt_ccid (rec_requisiton_val_c.segment1,
                             rec_requisiton_val_c.segment2,
                             rec_requisiton_val_c.segment3,
                             rec_requisiton_val_c.segment4,
                             ln_ir_org_id,
                             ln_tgt_charge_acct_id);

            IF ln_tgt_charge_acct_id IS NULL
            THEN
                lc_err_msg    :=
                    lc_err_msg || '/ Error in deriving Charge Account';
                lc_err_flag   := gc_yes_flag;
            END IF;

            OPEN get_location_id_c (ln_ir_dest_organization_id);

            FETCH get_location_id_c INTO ln_ir_location_id;

            IF get_location_id_c%NOTFOUND
            THEN
                ln_ir_location_id   := NULL;
            END IF;

            CLOSE get_location_id_c;


            IF ln_ir_location_id IS NULL
            THEN
                lc_err_msg    := lc_err_msg || '/ Error in deriving Location';
                lc_err_flag   := gc_yes_flag;
            END IF;

            IF lc_err_flag = gc_no_flag
            THEN
                UPDATE XXD_CONV.XXD_JP_DIRECT_PO_CONV_STG_T
                   SET record_status = gc_valid_record, error_message = NULL, tgt_ir_src_inv_org_id = ln_ir_src_organization_id,
                       tgt_ir_dest_inv_org_id = ln_ir_dest_organization_id, tgt_vendor_id = ln_vendor_id, tgt_vendor_site_id = ln_vendor_site_id,
                       tgt_line_type_id = ln_line_type_id, tgt_inv_item_id = ln_inv_item_id, tgt_inv_item_desc = lc_inv_item_desc,
                       tgt_agent_id = ln_agent_id, tgt_ir_org_id = ln_ir_org_id, tgt_charge_acct_id = ln_tgt_charge_acct_id,
                       tgt_ir_location_id = ln_ir_location_id
                 WHERE record_id = rec_requisiton_val_c.record_id;

                ln_success_cnt   := ln_success_cnt + 1;
            ELSE
                UPDATE XXD_CONV.XXD_JP_DIRECT_PO_CONV_STG_T
                   SET record_status = gc_error_record, error_message = SUBSTR (lc_err_msg, 1, 100), tgt_ir_src_inv_org_id = ln_ir_src_organization_id,
                       tgt_ir_dest_inv_org_id = ln_ir_dest_organization_id, tgt_vendor_id = ln_vendor_id, tgt_vendor_site_id = ln_vendor_site_id,
                       tgt_line_type_id = ln_line_type_id, tgt_inv_item_id = ln_inv_item_id, tgt_inv_item_desc = lc_inv_item_desc,
                       tgt_agent_id = ln_agent_id, tgt_ir_org_id = ln_ir_org_id, tgt_charge_acct_id = ln_tgt_charge_acct_id,
                       tgt_ir_location_id = ln_ir_location_id
                 WHERE record_id = rec_requisiton_val_c.record_id;

                ln_val_fail_cnt   := ln_val_fail_cnt + 1;
            END IF;
        END LOOP;

        COMMIT;
    END validate_requisition_prc;

    /* **************************************************************************************************
     Function  Name: get_agent_name
     Description: This function counts the total number of records in staging table for a particular status.
     Parameters:
     Name                     Type          Description
     ==============           ======       =============================================
     p_table_name             IN           Staging table name .
     p_status                 IN           Record status in stage table.
     p_request_id             IN           Request id for current set of records.
     ************************************************************************************************** */


    PROCEDURE import_requisition_prc (p_batch_id IN NUMBER, x_retcode OUT NUMBER, x_errbuff OUT VARCHAR2)
    IS
        CURSOR get_valid_req_c IS
            SELECT DISTINCT tgt_ir_org_id
              FROM XXD_CONV.XXD_JP_DIRECT_PO_CONV_STG_T xpr
             WHERE     1 = 1
                   AND record_status = gc_valid_record
                   AND EXISTS
                           (SELECT 1
                              FROM po_requisitions_interface_all pri
                             WHERE     pri.req_number_segment1 =
                                       xpr.requisition_number
                                   AND batch_id = p_batch_id)
                   AND INTERNAL_REQ_BATCH_SEQ = p_batch_id;


        TYPE request_id_tbl IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id                      request_id_tbl;
        lc_phase                      VARCHAR2 (100);
        lc_status                     VARCHAR2 (100);
        lc_dev_phase                  VARCHAR2 (100);
        lc_dev_status                 VARCHAR2 (100);
        lc_message                    VARCHAR2 (100);
        lb_wait_for_request           BOOLEAN := FALSE;
        lb_get_request_status         BOOLEAN := FALSE;
        ln_counter                    NUMBER := 0;
        ln_request_id                 NUMBER;
        request_submission_failed     EXCEPTION;
        request_completion_abnormal   EXCEPTION;
    BEGIN
        FOR rec_get_valid_req IN get_valid_req_c
        LOOP
            ln_counter   := ln_counter + 1;
            gc_code_pointer   :=
                   'Calling standard requisition import program for Batch /Org : '
                || p_batch_id
                || ' / '
                || rec_get_valid_req.tgt_ir_org_id;
            MO_GLOBAL.init ('PO');
            mo_global.set_policy_context ('S',
                                          rec_get_valid_req.tgt_ir_org_id);
            FND_REQUEST.SET_ORG_ID (rec_get_valid_req.tgt_ir_org_id);


            ln_request_id   :=
                fnd_request.submit_request (
                    application   => 'PO',
                    PROGRAM       => 'REQIMPORT',
                    description   => 'Requisition Import',
                    start_time    => SYSDATE,
                    sub_request   => FALSE,
                    argument1     => NULL,
                    argument2     => p_batch_id,
                    argument3     => 'ALL',
                    argument4     => NULL,
                    argument5     => 'N',
                    argument6     => 'N');

            IF ln_request_id > 0
            THEN
                COMMIT;
                l_req_id (ln_counter)   := ln_request_id;
            END IF;
        END LOOP;

        IF ln_counter > 0
        THEN
            --Waits for the Child requests completion
            FOR i IN l_req_id.FIRST .. l_req_id.LAST
            LOOP
                BEGIN
                    IF l_req_id (i) IS NOT NULL
                    THEN
                        LOOP
                            lc_dev_phase    := NULL;
                            lc_dev_status   := NULL;
                            gc_code_pointer   :=
                                'Calling fnd_concurrent.wait_for_request in  Requisition Import process  ';

                            lb_wait_for_request   :=
                                fnd_concurrent.wait_for_request (
                                    request_id   => l_req_id (i),
                                    interval     => 1,
                                    max_wait     => 1,
                                    phase        => lc_phase,
                                    status       => lc_status,
                                    dev_phase    => lc_dev_phase,
                                    dev_status   => lc_dev_status,
                                    MESSAGE      => lc_message);

                            IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                            THEN
                                EXIT;
                            END IF;
                        END LOOP;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        gc_code_pointer   :=
                            'Error message ' || SUBSTR (SQLERRM, 1, 240);
                        debug_log (gc_code_pointer);
                END;
            END LOOP;
        ELSE
            gc_code_pointer   := 'no data inserted into req interface table';
            debug_log (gc_code_pointer);
        END IF;



        UPDATE XXD_CONV.XXD_JP_DIRECT_PO_CONV_STG_T
           SET record_status   = gc_processed_record
         WHERE     po_number IN
                       (SELECT segment1 FROM po_requisition_headers_all)
               AND record_status = gc_valid_record;

        COMMIT;
    ---- Once the import programs complete -  generate an output report to show success and failure records



    END import_requisition_prc;

    /* **************************************************************************************************
   Function  Name: get_agent_name
   Description: This function counts the total number of records in staging table for a particular status.
   Parameters:
   Name                     Type          Description
   ==============           ======       =============================================
   p_table_name             IN           Staging table name .
   p_status                 IN           Record status in stage table.
   p_request_id             IN           Request id for current set of records.
   ************************************************************************************************** */

    PROCEDURE call_order_import (p_retcode      OUT NOCOPY NUMBER,
                                 p_errbuf       OUT NOCOPY VARCHAR2)
    IS
        CURSOR get_distinct_org_id_c1 IS
            SELECT DISTINCT ohia.org_id
              FROM xxd_conv.XXD_JP_DIRECT_PO_CONV_STG_T xprc, po_requisition_headers_all prha, oe_headers_iface_all ohia
             WHERE     1 = 1
                   AND record_status = gc_processed_record
                   AND prha.segment1 = xprc.requisition_number
                   AND ohia.orig_sys_document_ref =
                       TO_CHAR (prha.requisition_header_id)
                   AND xprc.tgt_ir_org_id = prha.org_id;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id              request_table;
        lb_wait_for_request   BOOLEAN := FALSE;

        ln_request_id         NUMBER;

        lc_dev_phase          VARCHAR2 (100);
        lc_dev_status         VARCHAR2 (100);
        lc_phase              VARCHAR2 (100);
        lc_status             VARCHAR2 (100);
        lc_message            VARCHAR2 (100);
        ln_org_id             NUMBER;
        ln_loop_counter       NUMBER := 1;
        ln_resp_id            NUMBER;
        ln_app_id             NUMBER;
    BEGIN
        OPEN get_distinct_org_id_c1;

        LOOP
            ln_org_id   := NULL;

            FETCH get_distinct_org_id_c1 INTO ln_org_id;

            EXIT WHEN get_distinct_org_id_c1%NOTFOUND;

            set_application_context (ln_resp_id, ln_app_id);

            mo_global.init ('ONT');
            mo_global.set_policy_context ('S', ln_org_id);
            FND_REQUEST.SET_ORG_ID (ln_org_id);

            ln_request_id   :=
                FND_REQUEST.SUBMIT_REQUEST (application   => 'ONT',
                                            program       => 'OEOIMP',
                                            description   => 'Order Import',
                                            start_time    => SYSDATE,
                                            sub_request   => NULL,
                                            argument1     => ln_org_id,
                                            argument2     => NULL,
                                            argument3     => NULL,
                                            argument4     => NULL,
                                            argument5     => 'N',
                                            argument6     => '1',
                                            argument7     => '4',
                                            argument8     => NULL,
                                            argument9     => NULL,
                                            argument10    => NULL,
                                            argument11    => 'Y',
                                            argument12    => 'N',
                                            argument13    => 'Y',
                                            argument14    => ln_org_id,
                                            argument15    => 'N');


            IF ln_request_id > 0
            THEN
                COMMIT;
                l_req_id (ln_loop_counter)   := ln_request_id;
                ln_loop_counter              := ln_loop_counter + 1;
            --   ELSE
            --      ROLLBACK;
            END IF;
        END LOOP;

        CLOSE get_distinct_org_id_c1;

        --fnd_file.put_line (fnd_file.LOG, 'Test4');
        IF ln_request_id > 0
        THEN
            gc_code_pointer   :=
                'Waiting for child requests in Order Import process  ';

            --Waits for the Child requests completion
            FOR rec IN l_req_id.FIRST .. l_req_id.LAST
            LOOP
                BEGIN
                    IF l_req_id (rec) IS NOT NULL
                    THEN
                        LOOP
                            lc_dev_phase    := NULL;
                            lc_dev_status   := NULL;


                            gc_code_pointer   :=
                                'Calling fnd_concurrent.wait_for_request in  Order Import process  ';

                            lb_wait_for_request   :=
                                fnd_concurrent.wait_for_request (
                                    request_id   => l_req_id (rec),
                                    interval     => 1,
                                    max_wait     => 1,
                                    phase        => lc_phase,
                                    status       => lc_status,
                                    dev_phase    => lc_dev_phase,
                                    dev_status   => lc_dev_status,
                                    MESSAGE      => lc_message);

                            IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                            THEN
                                EXIT;
                            END IF;
                        END LOOP;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        gc_code_pointer   :=
                            'Error message ' || SUBSTR (SQLERRM, 1, 240);
                        debug_log (gc_code_pointer);
                END;
            END LOOP;
        ELSE
            gc_code_pointer   :=
                'no data inserted into order interface table';
            debug_log (gc_code_pointer);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            gc_code_pointer   := 'ERROR WHILE ORDER IMPORT' || SQLERRM;
            debug_log (gc_code_pointer);
    END CALL_ORDER_IMPORT;

    /* **************************************************************************************************
   Function  Name: get_agent_name
   Description: This function counts the total number of records in staging table for a particular status.
   Parameters:
   Name                     Type          Description
   ==============           ======       =============================================
   p_table_name             IN           Staging table name .
   p_status                 IN           Record status in stage table.
   p_request_id             IN           Request id for current set of records.
   ************************************************************************************************** */

    PROCEDURE xxd_order_import (p_retcode      OUT NOCOPY NUMBER,
                                p_errbuf       OUT NOCOPY VARCHAR2)
    IS
        CURSOR get_distinct_org_id_c IS
            SELECT DISTINCT prha.org_id
              FROM xxd_conv.XXD_JP_DIRECT_PO_CONV_STG_T xprc, po_requisition_headers_all prha
             WHERE     1 = 1
                   --AND SCENARIO = 'REGULAR'
                   AND record_status = gc_processed_record
                   AND prha.segment1 = xprc.requisition_number
                   AND xprc.tgt_ir_org_id = prha.org_id;



        CURSOR Get_order_num_c IS
            SELECT DISTINCT requisition_number, PRHA.REQUISITION_HEADER_ID, xprc.ORDER_NUMBER,
                            XPRC.ISO_CREATION_DATE, xprc.order_type, xprc.conversion_type_code
              FROM xxd_conv.XXD_JP_DIRECT_PO_CONV_STG_T xprc, po_requisition_headers_all prha, oe_headers_iface_all ohia
             WHERE     1 = 1
                   AND record_status = gc_processed_record
                   AND ohia.orig_sys_document_ref =
                       TO_CHAR (prha.requisition_header_id)
                   AND prha.segment1 = xprc.requisition_number
                   AND xprc.tgt_ir_org_id = prha.org_id;


        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id              request_table;
        lb_wait_for_request   BOOLEAN := FALSE;

        ln_request_id         NUMBER;

        lc_dev_phase          VARCHAR2 (100);
        lc_dev_status         VARCHAR2 (100);
        lc_phase              VARCHAR2 (100);
        lc_status             VARCHAR2 (100);
        lc_message            VARCHAR2 (100);
        ln_org_id             NUMBER;
        lcu_Get_order_num_c   Get_order_num_c%ROWTYPE;

        ln_batch_no           NUMBER;
        ln_resp_id            NUMBER;
        ln_counter            NUMBER;
        ln_app_id             NUMBER;
        ln_loop_counter       NUMBER := 1;
    BEGIN
        set_application_context (ln_resp_id, ln_app_id);

        OPEN get_distinct_org_id_c;

        LOOP
            ln_org_id   := NULL;

            FETCH get_distinct_org_id_c INTO ln_org_id;

            EXIT WHEN get_distinct_org_id_c%NOTFOUND;

            gc_code_pointer   :=
                'Invoking Sales Order import program for org : ' || ln_org_id;
            debug_log (gc_code_pointer);

            MO_GLOBAL.init ('PO');
            mo_global.set_policy_context ('S', ln_org_id);
            FND_REQUEST.SET_ORG_ID (ln_org_id);
            DBMS_APPLICATION_INFO.set_client_info (ln_org_id);

            ln_request_id   :=
                fnd_request.submit_request (
                    application   => 'PO',
                    PROGRAM       => 'POCISO',
                    description   => 'Create Internal Orders',
                    start_time    => SYSDATE,
                    sub_request   => FALSE);

            IF ln_request_id > 0
            THEN
                COMMIT;
                l_req_id (ln_loop_counter)   := ln_request_id;
                ln_loop_counter              := ln_loop_counter + 1;
            END IF;
        END LOOP;

        CLOSE get_distinct_org_id_c;

        gc_code_pointer   :=
            'Waiting for child requests in Create internal process  ';
        debug_log (gc_code_pointer);


        IF ln_request_id > 0
        THEN
            --Waits for the Child requests completion
            FOR rec IN l_req_id.FIRST .. l_req_id.LAST
            LOOP
                BEGIN
                    IF l_req_id (rec) IS NOT NULL
                    THEN
                        LOOP
                            lc_dev_phase    := NULL;
                            lc_dev_status   := NULL;


                            gc_code_pointer   :=
                                'Calling fnd_concurrent.wait_for_request in  Create internal process  ';
                            debug_log (gc_code_pointer);

                            lb_wait_for_request   :=
                                fnd_concurrent.wait_for_request (
                                    request_id   => l_req_id (rec),
                                    interval     => 1,
                                    max_wait     => 1,
                                    phase        => lc_phase,
                                    status       => lc_status,
                                    dev_phase    => lc_dev_phase,
                                    dev_status   => lc_dev_status,
                                    MESSAGE      => lc_message);

                            IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                            THEN
                                EXIT;
                            END IF;
                        END LOOP;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        gc_code_pointer   :=
                            'Unhandeled exceptions occured: ';
                        debug_log (gc_code_pointer);
                        debug_log (
                            'Error message ' || SUBSTR (SQLERRM, 1, 240));
                END;
            END LOOP;
        ELSE
            debug_log ('no data inserted into req interface table');
        END IF;



        gc_code_pointer   :=
            'Updating Order number as PO number in OE_HEADERS_IFACE_ALL';
        debug_log (gc_code_pointer);

        OPEN Get_order_num_c;

        LOOP
            FETCH Get_order_num_c INTO lcu_Get_order_num_c;

            EXIT WHEN Get_order_num_c%NOTFOUND;

            UPDATE oe_headers_iface_all
               SET order_number = lcu_get_order_num_c.requisition_number, booked_flag = 'Y'
             --    order_type_id=1134,
             --      order_type= 'DC to DC Transfer ? Macau'
             --      conversion_type_code = lcu_get_order_num_c.conversion_type_code
             WHERE orig_sys_document_ref =
                   TO_CHAR (lcu_Get_order_num_c.requisition_header_id);


            IF lcu_Get_order_num_c.iso_creation_date IS NOT NULL
            THEN
                UPDATE oe_headers_iface_all
                   SET creation_date = lcu_get_order_num_c.iso_creation_date
                 WHERE orig_sys_document_ref =
                       TO_CHAR (lcu_Get_order_num_c.requisition_header_id);
            END IF;
        END LOOP;

        COMMIT;

        CLOSE Get_order_num_c;

        gc_code_pointer   := 'Calling Order import Program ';
        debug_log (gc_code_pointer);


        CALL_ORDER_IMPORT (p_retcode, p_errbuf);
    END xxd_order_import;

    PROCEDURE import_internal_req_prc (x_retcode   OUT NUMBER,
                                       x_errbuff   OUT VARCHAR2)
    IS
        CURSOR requisition_int_c IS
            SELECT *
              FROM xxd_conv.XXD_JP_DIRECT_PO_CONV_STG_T xpr
             WHERE     1 = 1
                   AND record_status = gc_valid_record
                   AND NOT EXISTS
                           (SELECT 1
                              FROM po_requisitions_interface_all pri
                             WHERE pri.req_number_segment1 =
                                   xpr.requisition_number);


        TYPE xxd_requisition_int_tab IS TABLE OF requisition_int_c%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_req_interface_tbl   xxd_requisition_int_tab;
        ln_req_batch           NUMBER;
        ln_succes_cnt          NUMBER := 0;
    BEGIN
        gc_code_pointer   := 'generate requisition batch sequence';
        debug_log (gc_code_pointer);

        BEGIN
            SELECT XXD_ONT_DS_SO_REQ_BATCH_S.NEXTVAL
              INTO ln_req_batch
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                gc_code_pointer   := 'Error in retrieving Req sequence batch';
                debug_log (gc_code_pointer);
        END;


        gc_code_pointer   := 'Inserting into po_requisitions_interface_all';
        debug_log (gc_code_pointer);

        OPEN requisition_int_c;

        LOOP
            FETCH requisition_int_c
                BULK COLLECT INTO lt_req_interface_tbl
                LIMIT gn_limit;

            FORALL i IN 1 .. lt_req_interface_tbl.COUNT SAVE EXCEPTIONS
                INSERT INTO po_requisitions_interface_all (
                                batch_id,
                                req_number_segment1,
                                interface_source_code,
                                org_id,
                                destination_type_code,
                                authorization_status,
                                preparer_id,
                                charge_account_id,
                                source_type_code,
                                unit_of_measure,
                                line_type_id,
                                LINE_NUM,
                                REQUISITION_TYPE,
                                --category_id,
                                unit_price,
                                quantity,
                                destination_organization_id,
                                SOURCE_ORGANIZATION_ID,
                                deliver_to_location_id,
                                deliver_to_requestor_id,
                                item_description,
                                item_id,
                                NEED_BY_DATE,
                                header_attribute_category,
                                line_attribute_category,
                                line_attribute12,
                                line_attribute13,
                                line_attribute14,
                                line_attribute15)
                     VALUES (ln_req_batch, lt_req_interface_tbl (i).requisition_number, lt_req_interface_tbl (i).interface_source_code, lt_req_interface_tbl (i).tgt_ir_org_id, lt_req_interface_tbl (i).destination_type_code, lt_req_interface_tbl (i).authorization_status, lt_req_interface_tbl (i).tgt_agent_id, lt_req_interface_tbl (i).tgt_charge_acct_id, 'INVENTORY', lt_req_interface_tbl (i).unit_meas_lookup_code, lt_req_interface_tbl (i).tgt_line_type_id, lt_req_interface_tbl (i).po_line_num, lt_req_interface_tbl (i).requisition_type, lt_req_interface_tbl (i).unit_price, lt_req_interface_tbl (i).quantity, lt_req_interface_tbl (i).tgt_ir_dest_inv_org_id, lt_req_interface_tbl (i).tgt_ir_src_inv_org_id, lt_req_interface_tbl (i).tgt_ir_location_id, lt_req_interface_tbl (i).tgt_agent_id, lt_req_interface_tbl (i).tgt_inv_item_desc, lt_req_interface_tbl (i).tgt_inv_item_id, lt_req_interface_tbl (i).need_by_date, 'REQ_CONVERSION', 'REQ_CONVERSION', lt_req_interface_tbl (i).SHIPMENT_NUM, lt_req_interface_tbl (i).po_line_num, lt_req_interface_tbl (i).po_line_id
                             , lt_req_interface_tbl (i).requisition_line_id);

            COMMIT;
            EXIT WHEN requisition_int_c%NOTFOUND;
        END LOOP;

        CLOSE requisition_int_c;

        BEGIN
            UPDATE XXD_CONV.XXD_JP_DIRECT_PO_CONV_STG_T xpr
               SET internal_req_batch_seq   = ln_req_batch
             WHERE     1 = 1
                   AND record_status = gc_valid_record
                   AND EXISTS
                           (SELECT 1
                              FROM po_requisitions_interface_all pri
                             WHERE     pri.req_number_segment1 =
                                       xpr.requisition_number
                                   AND batch_id = ln_req_batch);
        EXCEPTION
            WHEN OTHERS
            THEN
                gc_code_pointer   :=
                    'Error in Updating XXD_CONV.XXD_JP_DIRECT_PO_CONV_STG_T batch sequence';
                debug_log (gc_code_pointer);
        END;


        import_requisition_prc (ln_req_batch, x_retcode, x_errbuff);
    END import_internal_req_prc;

    /* **************************************************************************************************
 Procedure  Name: call_purchase_req_import
 Description: This procedure creates Purchase requisition
 Parameters:
 Name                     Type          Description
 ==============           ======       =============================================
 x_retcode                IN           Return code .
 x_errbuf                 IN           Error message.

 ************************************************************************************************** */

    PROCEDURE call_purchase_req_import (p_errbuf OUT NOCOPY VARCHAR2, p_retcode OUT NOCOPY NUMBER, p_batch_id IN NUMBER)
    IS
        CURSOR get_distinct_org_id_c IS
            SELECT DISTINCT org_id
              FROM po_requisitions_interface_all
             WHERE INTERFACE_SOURCE_CODE = 'CTO' AND BATCH_ID = P_BATCH_ID;


        ln_loop_counter       NUMBER := 1;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id              request_table;
        lb_wait_for_request   BOOLEAN := FALSE;

        ln_request_id         NUMBER;

        lc_dev_phase          VARCHAR2 (100);
        lc_dev_status         VARCHAR2 (100);
        lc_phase              VARCHAR2 (100);
        lc_status             VARCHAR2 (100);
        lc_message            VARCHAR2 (100);
        ln_org_id             NUMBER;
    BEGIN
        -----ADDED TO UPDATE ATTRIBUTE15 IN PURCHASE REQ----
        OPEN get_distinct_org_id_c;

        debug_log (' IN  get_distinct_org_id_c cursor');

        LOOP
            ln_org_id   := NULL;

            FETCH get_distinct_org_id_c INTO ln_org_id;

            EXIT WHEN get_distinct_org_id_c%NOTFOUND;


            MO_GLOBAL.init ('PO');
            mo_global.set_policy_context ('S', ln_org_id);
            FND_REQUEST.SET_ORG_ID (ln_org_id);
            debug_log ('Org id ' || mo_global.get_current_org_id);



            ln_request_id   :=
                fnd_request.submit_request (
                    application   => 'PO',
                    PROGRAM       => 'REQIMPORT',
                    description   => 'Requisition Import',
                    start_time    => SYSDATE,
                    sub_request   => FALSE,
                    argument1     => NULL,
                    argument2     => P_BATCH_ID,
                    argument3     => 'ALL',
                    argument4     => NULL,
                    argument5     => 'N',
                    argument6     => 'N');
            debug_log ('ln_request_id' || ln_request_id);

            IF ln_request_id > 0
            THEN
                COMMIT;
                l_req_id (ln_loop_counter)   := ln_request_id;
                ln_loop_counter              := ln_loop_counter + 1;
            --  ELSE
            --    ROLLBACK;
            END IF;
        END LOOP;

        CLOSE get_distinct_org_id_c;

        --debug_log( 'Test4');

        debug_log ('Test4');
        gc_code_pointer   :=
            'Waiting for child requests in Requisition Import process  ';

        IF ln_request_id > 0
        THEN
            --Waits for the Child requests completion
            FOR rec IN l_req_id.FIRST .. l_req_id.LAST
            LOOP
                BEGIN
                    IF l_req_id (rec) IS NOT NULL
                    THEN
                        LOOP
                            lc_dev_phase    := NULL;
                            lc_dev_status   := NULL;


                            gc_code_pointer   :=
                                'Calling fnd_concurrent.wait_for_request in  Requisition Import process  ';

                            lb_wait_for_request   :=
                                fnd_concurrent.wait_for_request (
                                    request_id   => l_req_id (rec),
                                    interval     => 1,
                                    max_wait     => 1,
                                    phase        => lc_phase,
                                    status       => lc_status,
                                    dev_phase    => lc_dev_phase,
                                    dev_status   => lc_dev_status,
                                    MESSAGE      => lc_message);

                            IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                            THEN
                                EXIT;
                            END IF;
                        END LOOP;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        debug_log ('Code pointer ' || gc_code_pointer);

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Error message ' || SUBSTR (SQLERRM, 1, 240));
                END;
            END LOOP;
        ELSE
            debug_log ('no data inserted into req interface table');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_log (' Exception REQ IMPORT occurred ' || SQLERRM);
    END call_purchase_req_import;

    /* **************************************************************************************************
   Function  Name: create_purchase_requisition
   Description: This procedure creates Purchase requisition
   Parameters:
   Name                     Type          Description
   ==============           ======       =============================================
   x_retcode                IN           Return code .
   x_errbuf                 IN           Error message.

   ************************************************************************************************** */

    PROCEDURE create_purchase_requisition (x_retcode   OUT NUMBER,
                                           x_errbuf    OUT VARCHAR2)
    AS
        CURSOR get_line_notf_act_c --(      p_order_number NUMBER)
                                   IS
            SELECT TO_NUMBER (st.item_key) line_id, oha.header_id header_id, wpa.activity_name
              FROM apps.wf_item_activity_statuses st, apps.wf_process_activities wpa, apps.oe_order_lines_all ola,
                   apps.oe_order_headers_all oha
             --  hr_operating_units hou
             WHERE     wpa.instance_id = st.process_activity
                   AND st.item_type = 'OEOL'
                   AND wpa.activity_name IN ('LINE_SCHEDULING', 'SCHEDULING_ELIGIBLE', 'CREATE_SUPPLY_ORDER_ELIGIBLE',
                                             'BOOK_WAIT_FOR_H')
                   AND st.activity_status = 'NOTIFIED'
                   AND st.item_key = ola.line_id
                   --   AND hou.name = 'Deckers Macau OU'
                   --   AND oha.org_id = hou.organization_id
                   AND ola.header_id = oha.header_id
                   AND EXISTS
                           (SELECT 1
                              FROM xxd_conv.XXD_JP_DIRECT_PO_CONV_STG_T XPRC
                             WHERE     XPRC.REQUISITION_NUMBER =
                                       oha.ORIG_SYS_DOCUMENT_REF
                                   AND XPRC.record_status = 'P');


        CURSOR get_pr_attribute_c IS
            SELECT DISTINCT OOIA.LINE_ID, --PRLA.attribute15 old_IR_REQ_LINE_ID,
                                          xprc.po_line_id, xprc.REQUISITION_NUMBER,
                            xprc.purchase_req_number, XPRC.PR_CREATION_DATE, XPRC.UNIT_PRICE,
                            xprc.shipment_num, xprc.tgt_agent_id, xprc.tgt_vendor_id,
                            xprc.tgt_vendor_site_id, xprc.NEED_BY_DATE, --Added on 10-AUG-2015
                                                                        xprc.DESTINATION_SUBINVENTORY --Added on 10-AUG-2015
              FROM oe_order_lines_all ooia, oe_order_headers_all ooha, po_requisition_lines_all prla,
                   xxd_conv.XXD_JP_DIRECT_PO_CONV_STG_T XPRC
             WHERE     OOHA.source_document_id = PRLA.requisition_header_id
                   AND XPRC.record_status = 'P'
                   AND OOHA.HEADER_ID = OOIA.HEADER_ID
                   AND PRLA.REQUISITION_LINE_ID =
                       OOIA.source_document_line_id
                   AND XPRC.PO_LINE_ID = PRLA.ATTRIBUTE14 --  needs to uncomment in ver 1.3
                   AND XPRC.SHIPMENT_NUM = PRLA.ATTRIBUTE12
                   AND XPRC.REQUISITION_NUMBER = ooha.ORIG_SYS_DOCUMENT_REF;



        CURSOR get_emp_id_c (p_user_id NUMBER)
        IS
            SELECT fu.employee_id
              FROM fnd_user fu, per_all_people_f ppf
             WHERE     fu.employee_id = ppf.person_id
                   AND TRUNC (SYSDATE) BETWEEN NVL (ppf.EFFECTIVE_START_DATE,
                                                    SYSDATE)
                                           AND NVL (ppf.EFFECTIVE_END_DATE,
                                                    SYSDATE)
                   AND fu.user_id = p_user_id;



        l_linenum                     NUMBER;
        l_old_REQUISITION_header_ID   NUMBER;
        l_attribute15                 NUMBER;

        ln_emp_id                     NUMBER;
        ln_success_cnt                NUMBER := 0;
        ln_rec_count                  NUMBER;
        v_requisition_header_id       NUMBER;

        ln_batch_no                   NUMBER;
        lb_retry                      BOOLEAN;
        lb_lines                      BOOLEAN := FALSE;
        lc_message                    VARCHAR2 (1);
        ln_user_id                    NUMBER := fnd_global.user_id;
        ln_batch_id                   NUMBER;
    BEGIN
        gc_code_pointer   := 'call workflow background process';
        debug_log (gc_code_pointer);

        FOR cur_get_line_notif_act IN get_line_notf_act_c
        LOOP
            lb_retry   := FALSE;
            lb_lines   := FALSE;

            wf_engine.completeactivity ('OEOL', cur_get_line_notif_act.line_id, cur_get_line_notif_act.activity_name
                                        , NULL);
        END LOOP;


        gc_code_pointer   :=
            'call workflow background process for Order lines';
        debug_log (gc_code_pointer);
        wf_engine.background ('OEOL', NULL, NULL,
                              TRUE, FALSE, FALSE);


        -----ADDED TO UPDATE ATTRIBUTE15 IN PURCHASE REQ----

        gc_code_pointer   := 'Generating PR batch seq';
        debug_log (gc_code_pointer);

        SELECT apps.XXD_ONT_DS_SO_REQ_BATCH_S.NEXTVAL
          INTO ln_batch_id
          FROM DUAL;


        gc_code_pointer   := 'Batch Generated : ' || ln_batch_id;
        debug_log (gc_code_pointer);

        BEGIN
            gc_code_pointer   := 'Updating PR attributes';

            FOR rec_get_pr_attribute_c IN get_pr_attribute_c
            LOOP
                ln_success_cnt   := ln_success_cnt + 1;

                UPDATE po_requisitions_interface_all pria
                   SET LINE_ATTRIBUTE15 = rec_get_pr_attribute_c.po_line_id, DELIVER_TO_REQUESTOR_ID = rec_get_pr_attribute_c.tgt_agent_id, PREPARER_ID = rec_get_pr_attribute_c.tgt_agent_id,
                       -- NVL (rec_get_pr_attribute_c.old_IR_REQ_LINE_ID,rec_get_pr_attribute_c.po_line_id),
                       REQ_NUMBER_SEGMENT1 = NVL (rec_get_pr_attribute_c.PURCHASE_REQ_NUMBER, -- needs to modify in ver 1.3
                                                                                              rec_get_pr_attribute_c.REQUISITION_NUMBER), SUGGESTED_VENDOR_SITE_ID = rec_get_pr_attribute_c.tgt_vendor_site_id, SUGGESTED_VENDOR_ID = rec_get_pr_attribute_c.tgt_vendor_id,
                       CREATION_DATE = NVL (rec_get_pr_attribute_c.PR_CREATION_DATE, SYSDATE), UNIT_PRICE = rec_get_pr_attribute_c.UNIT_PRICE, --Added on 12-MAY-2015
                                                                                                                                               SUGGESTED_BUYER_ID = rec_get_pr_attribute_c.tgt_agent_id,
                       LINE_ATTRIBUTE14 = rec_get_pr_attribute_c.shipment_num, --- added on 19th may                                 -- need to modify in ver 1.3
                                                                               line_attribute_category = 'REQ_CONVERSION', --Start
                                                                                                                           DESTINATION_SUBINVENTORY = UPPER (rec_get_pr_attribute_c.DESTINATION_SUBINVENTORY), ----added on 07-aug-15
                       NEED_BY_DATE = rec_get_pr_attribute_c.NEED_BY_DATE, ----added on 07-aug-15
                                                                           --End
                                                                           request_id = NULL, process_flag = NULL,
                       batch_id = ln_batch_id
                 WHERE rec_get_pr_attribute_c.LINE_ID =
                       pria.INTERFACE_SOURCE_LINE_ID;
            END LOOP;
        EXCEPTION
            WHEN OTHERS
            THEN
                debug_log (gc_code_pointer);
                gc_code_pointer   := 'Exception occurred ' || SQLERRM;
                debug_log (gc_code_pointer);
        END;

        gc_code_pointer   := 'Total rows updated : ' || ln_success_cnt;
        debug_log (gc_code_pointer);



        gc_code_pointer   := 'Initiate  call_purchase_req_import()';
        debug_log (gc_code_pointer);

        call_purchase_req_import (x_errbuf, x_retcode, ln_batch_id); -- nee to update in ver 1.3

        gc_code_pointer   := 'Program completed ';
        debug_log (gc_code_pointer);
    /*   IF ln_success_cnt = ln_rec_count
       THEN
          call_purchase_req_import (x_errbuf, x_retcode, ln_batch_id);
       ELSE
          fnd_file.put_line (
             fnd_file.LOG,
                'not all lines got updated'
             || ln_rec_count
             || ','
             || ln_success_cnt);
          fnd_file.put_line (fnd_file.LOG, 'BATCH ID : ' || ln_batch_id);
       END IF;

       */
    EXCEPTION
        WHEN OTHERS
        THEN
            gc_code_pointer   := 'Exception occurred ' || SQLERRM;
            debug_log (gc_code_pointer);
    END create_purchase_requisition;

    --Start on 30-JUN-2015
    PROCEDURE UPDATE_ORDER_ATTRIBUTE
    IS
        CURSOR get_line_id_c IS
                SELECT oola.line_id, pda.line_location_id, ooha.order_number
                  FROM mtl_reservations mr, oe_order_lines_all oola, po_requisition_lines_all prla,
                       po_req_distributions_all prda, po_distributions_all pda, oe_order_headers_all ooha
                 WHERE     mr.DEMAND_SOURCE_LINE_ID = oola.line_id
                       --AND ooha.header_id = 42586
                       AND mr.ORIG_SUPPLY_SOURCE_LINE_ID =
                           prla.REQUISITION_LINE_ID
                       AND ooha.header_id = oola.header_id
                       AND prla.REQUISITION_LINE_ID = prda.REQUISITION_LINE_ID
                       AND prda.DISTRIBUTION_ID = pda.REQ_DISTRIBUTION_ID
                       AND EXISTS
                               (SELECT 1
                                  FROM xxd_conv.XXD_JP_DIRECT_PO_CONV_STG_T XPRC
                                 WHERE     XPRC.REQUISITION_NUMBER =
                                           ooha.ORIG_SYS_DOCUMENT_REF
                                       AND XPRC.record_status = 'P')
            FOR UPDATE OF oola.attribute16;

        TYPE get_line_id_TAB IS TABLE OF get_line_id_c%ROWTYPE
            INDEX BY BINARY_INTEGER;

        get_line_id_T   get_line_id_TAB;
    BEGIN
        OPEN get_line_id_c;

        LOOP
            FETCH get_line_id_c BULK COLLECT INTO get_line_id_T LIMIT 5000;

            IF get_line_id_T.COUNT > 0
            THEN
                FORALL i IN 1 .. get_line_id_T.COUNT SAVE EXCEPTIONS
                    UPDATE oe_order_lines_all
                       SET attribute16   = get_line_id_T (i).line_location_id
                     WHERE line_id = get_line_id_T (i).line_id;
            ELSE
                EXIT;
            END IF;

            get_line_id_T.DELETE;
        END LOOP;

        CLOSE get_line_id_c;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF get_line_id_c%ISOPEN
            THEN
                CLOSE get_line_id_c;
            END IF;

            FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
            LOOP
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    SQLERRM (-(SQL%BULK_EXCEPTIONS (indx).ERROR_CODE)));
            END LOOP;
    END;

    --End on 30-JUN-2015

    -- +===================================================================+
    -- | Name  : SUBMIT_PO_REQUEST                                         |
    -- | Description      : Main Procedure to submit the purchase order    |
    -- |                    request                                        |
    -- |                                                                   |
    -- | Parameters : p_submit_openpo                                      |
    -- |                                                                   |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :                                                         |
    -- |                                                                   |
    -- +===================================================================+

    PROCEDURE submit_po_request (p_batch_id IN NUMBER, p_org_id IN NUMBER)
    IS
        ln_request_id              NUMBER := 0;

        lc_openpo_hdr_phase        VARCHAR2 (50);
        lc_openpo_hdr_status       VARCHAR2 (100);
        lc_openpo_hdr_dev_phase    VARCHAR2 (100);
        lc_openpo_hdr_dev_status   VARCHAR2 (100);
        lc_openpo_hdr_message      VARCHAR2 (3000);
        lc_submit_openpo           VARCHAR2 (10) := 'N';
        lb_openpo_hdr_req_wait     BOOLEAN;
        ln_resp_id                 NUMBER;
        ln_app_id                  NUMBER;
    BEGIN
        --fnd_file.put_line (fnd_file.LOG, 'p_org_id ' || p_org_id);

        set_application_context (ln_resp_id, ln_app_id);

        MO_GLOBAL.init ('PO');
        mo_global.set_policy_context ('S', p_org_id);
        FND_REQUEST.SET_ORG_ID (p_org_id);
        -- DBMS_APPLICATION_INFO.set_client_info (p_org_id);

        ln_request_id   :=
            fnd_request.submit_request (application   => 'PO',
                                        program       => 'POXPOPDOI',
                                        description   => NULL,
                                        start_time    => NULL,
                                        sub_request   => FALSE,
                                        argument1     => NULL,
                                        argument2     => 'STANDARD',
                                        argument3     => NULL,
                                        argument4     => 'N',
                                        argument5     => NULL,
                                        argument6     => 'APPROVED',
                                        argument7     => NULL,
                                        argument8     => p_batch_id,
                                        argument9     => p_org_id,
                                        argument10    => NULL,
                                        argument11    => NULL,
                                        argument12    => NULL,
                                        argument13    => NULL);



        COMMIT;

        IF ln_request_id = 0
        THEN
            debug_log ('Seeded Open PO import program POXPOPDOI failed ');
        ELSE
            -- wait for request to complete.
            lc_openpo_hdr_dev_phase   := NULL;
            lc_openpo_hdr_phase       := NULL;

            LOOP
                lb_openpo_hdr_req_wait   :=
                    FND_CONCURRENT.WAIT_FOR_REQUEST (
                        request_id   => ln_request_id,
                        interval     => 1,
                        max_wait     => 1,
                        phase        => lc_openpo_hdr_phase,
                        status       => lc_openpo_hdr_status,
                        dev_phase    => lc_openpo_hdr_dev_phase,
                        dev_status   => lc_openpo_hdr_dev_status,
                        MESSAGE      => lc_openpo_hdr_message);

                IF ((UPPER (lc_openpo_hdr_dev_phase) = 'COMPLETE') OR (UPPER (lc_openpo_hdr_phase) = 'COMPLETED'))
                THEN
                    lc_submit_openpo   := 'Y';

                    debug_log (
                           ' Open PO Import debug: request_id: '
                        || ln_request_id
                        || ', lc_openpo_hdr_dev_phase: '
                        || lc_openpo_hdr_dev_phase
                        || ',lc_openpo_hdr_phase: '
                        || lc_openpo_hdr_phase);

                    EXIT;
                END IF;
            END LOOP;
        -- p_submit_openpo := lc_submit_openpo;
        END IF;
    END submit_po_request;



    /* **************************************************************************************************
    Procedure  Name:  xxd_autocreate_po
    Description: This procedure creates Purchase orders
    Parameters:
    Name                     Type          Description
    ==============           ======       =============================================
    x_retcode                IN           Return code .
    x_errbuf                 IN           Error message.
    p_process                IN           This tells whether program should create IR / Sales Order
                                          or Purchase requisition or Purchase orders

    ************************************************************************************************** */

    PROCEDURE xxd_autocreate_po (x_errbuf       OUT NOCOPY VARCHAR2,
                                 x_retcode      OUT NOCOPY NUMBER)
    IS
        CURSOR get_distinct_po_c IS
            SELECT DISTINCT po_number
              FROM xxd_conv.XXD_JP_DIRECT_PO_CONV_STG_T stg1
             WHERE     1 = 1
                   AND record_status = 'P'
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxd_conv.XXD_JP_DIRECT_PO_CONV_STG_T stg2
                             WHERE     stg2.po_number = stg1.po_number
                                   AND stg2.record_status = 'E')
                   AND NOT EXISTS
                           (SELECT 1
                              FROM PO_HEADERS_ALL poh2
                             WHERE poh2.segment1 = stg1.po_number);

        CURSOR get_macau_org IS
            SELECT organization_id
              FROM hr_operating_units
             WHERE name LIKE 'Deckers Macau OU%';

        CURSOR po_headers_interface_c (p_po_number VARCHAR2)
        IS
              SELECT DISTINCT
                     'STANDARD' type_lookup_code,
                     xprc.vendor_site_code,
                     PRHA.org_id,
                     APS.VENDOR_ID vendor_id,
                     APSS.VENDOR_SITE_ID vendor_site_id,
                     prla.deliver_to_location_id,
                     Prla.quantity,
                     Prla.item_description,
                     prla.item_id,
                     prla.unit_meas_lookup_code,
                     Prla.unit_price,
                     prla.category_id,
                     prla.requisition_line_id,
                     prla.job_id,
                     HROU.organization_id ship_to_organization_id,
                     NVL (PRLA.currency_code, sob.currency_code) currency_code,
                     CASE
                         WHEN SOB.CURRENCY_CODE != PRLA.currency_code
                         THEN
                             PRLA.rate_type
                         ELSE
                             NULL
                     END rate_type,
                     CASE
                         WHEN SOB.CURRENCY_CODE != PRLA.currency_code
                         THEN
                             PRLA.rate_date
                         ELSE
                             NULL
                     END rate_date,
                     CASE
                         WHEN SOB.CURRENCY_CODE != PRLA.currency_code
                         THEN
                             PRLA.rate
                         ELSE
                             NULL
                     END rate,
                     NULL pcard_id,
                     apss.bill_to_location_id,
                     hrou.location_id SHIP_TO_LOCATION_ID,
                     prla.note_to_receiver,
                     prla.line_type_id,
                     'PO Line Locations Elements' shipment_attribute_CATEGORY,
                     MCB.SEGMENT1 BRAND,
                     'PO Data Elements' ATTRIBUTE_CATEGORY,
                     NULL ATTRIBUTE9,
                     NULL ATTRIBUTE8,
                     NULL ATTRIBUTE11,
                     NULL ATTRIBUTE10,
                     NVL (XPRC.PO_NUMBER, XPRC.requisition_number) PO_NUMBER,
                     NVL (XPRC.PO_NUMBER, XPRC.requisition_number) group_code,
                     xprc.po_line_num,
                     xprc.shipment_num,
                     XPRC.tgt_agent_id agent_id,
                     XPRC.po_header_id ATTRIBUTE15,
                     XPRC.PO_CREATION_DATE,
                     xprc.need_by_date,
                     XPRC.HEADER_ATTRIBUTE_CATEGORY,
                     XPRC.HEADER_ATTRIBUTE1,
                     XPRC.HEADER_ATTRIBUTE2,
                     XPRC.HEADER_ATTRIBUTE3,
                     XPRC.HEADER_ATTRIBUTE4,
                     XPRC.HEADER_ATTRIBUTE5,
                     XPRC.HEADER_ATTRIBUTE6,
                     XPRC.HEADER_ATTRIBUTE7,
                     XPRC.HEADER_ATTRIBUTE8,
                     XPRC.HEADER_ATTRIBUTE9,
                     XPRC.HEADER_ATTRIBUTE10,
                     XPRC.HEADER_ATTRIBUTE11,
                     XPRC.HEADER_ATTRIBUTE12,
                     XPRC.HEADER_ATTRIBUTE13,
                     XPRC.HEADER_ATTRIBUTE14,
                     'PO Data Elements' LINE_attribute_CATEGORY,
                     TRIM (mcb.segment1) LINE_attribute1,
                     TRIM (mcb.segment3) LINE_attribute2,
                     APSS.VENDOR_SITE_CODE LINE_attribute7,
                     XPRC.PO_HEADER_ID LINE_attribute14,
                     XPRC.po_line_id LINE_attribute15,
                     XPRC.LINE_attribute3,
                     XPRC.LINE_attribute5,
                     XPRC.LINE_attribute6,
                     XPRC.LINE_attribute8,
                     XPRC.LINE_attribute9,
                     XPRC.LINE_attribute10,
                     XPRC.LINE_attribute11,
                     XPRC.LINE_attribute12,
                     XPRC.LINE_attribute13,
                     --XPRC.LINE_attribute14,
                     --XPRC.LINE_attribute15,
                     XPRC.SHIPMENT_attribute1,
                     XPRC.SHIPMENT_attribute2,
                     XPRC.SHIPMENT_attribute3,
                     XPRC.SHIPMENT_attribute4,
                     XPRC.SHIPMENT_attribute5,
                     XPRC.SHIPMENT_attribute6,
                     XPRC.SHIPMENT_attribute7,
                     XPRC.SHIPMENT_attribute8,
                     XPRC.SHIPMENT_attribute9,
                     XPRC.SHIPMENT_attribute10,
                     XPRC.SHIPMENT_attribute11,
                     XPRC.SHIPMENT_attribute12,
                     XPRC.SHIPMENT_attribute13,
                     XPRC.SHIPMENT_attribute14,
                     XPRC.SHIPMENT_attribute15,
                     XPRC.DESTINATION_SUBINVENTORY,
                     XPRC.DIST_QUANTITY,
                     xprc.promised_date
                FROM XXD_CONV.XXD_JP_DIRECT_PO_CONV_STG_T xprc, PO_REQUISITION_HEADERS_ALL prha, po_requisition_lines_all prla,
                     po_req_distributions_all prda, hr_organization_units hrou, mtl_item_categories mic,
                     MTL_CATEGORIES_B mcb, FND_ID_FLEX_STRUCTURES ffs, ap_suppliers aps,
                     ap_supplier_sites_all apss, GL_SETS_OF_BOOKS SOB
               WHERE     xprc.requisition_number = prha.segment1
                     AND prha.interface_source_code = 'CTO'
                     AND prha.type_lookup_code = 'PURCHASE'
                     AND prha.authorization_status = 'APPROVED'
                     AND prha.requisition_header_id =
                         prla.requisition_header_id
                     AND xprc.record_status = 'P'
                     AND prda.requisition_line_id = prla.requisition_line_id
                     AND prla.destination_organization_id =
                         hrou.organization_id
                     AND prla.item_id = mic.inventory_item_id
                     AND prla.destination_organization_id = mic.organization_id
                     AND mic.category_id = mcb.category_id
                     AND mcb.structure_id = ffs.id_flex_num
                     AND ffs.id_flex_structure_code = 'ITEM_CATEGORIES'
                     AND xprc.vendor_name = aps.vendor_name
                     AND xprc.vendor_site_code = apss.vendor_site_code
                     AND aps.vendor_id = apss.vendor_id
                     AND prha.org_id = apss.org_id
                     AND prda.set_of_books_id = sob.set_of_books_id
                     AND xprc.po_line_id = prla.ATTRIBUTE15
                     AND xprc.shipment_num = prla.attribute14
                     AND xprc.po_number = p_po_number
            ORDER BY po_number, po_line_num ASC;


        CURSOR Get_EDI_c IS
            SELECT DISTINCT pha.po_header_id, XPO.EDI_PROCESSED_FLAG, xpo.EDI_PROCESSED_STATUS
              FROM po_headers_all pha, hr_operating_units hou, XXD_JP_DIRECT_PO_CONV_STG_T XPO,
                   hr_operating_units xhou
             WHERE     pha.org_id = hou.organization_id
                   AND hou.name = 'Deckers Macau OU'
                   AND xpo.PO_NUMBER = pha.segment1;

        --lcu_Get_EDI_c Get_EDI_c%rowtype;



        cur_po_errors_rec            VARCHAR2 (250);
        v_document_creation_method   po_headers_all.document_creation_method%TYPE;
        V_document_id                NUMBER;
        v_interface_header_id        NUMBER;
        lc_return_status             VARCHAR2 (50);
        lc_po_Msg_Count              VARCHAR2 (50);
        lc_po_Msg_data               VARCHAR2 (50);
        ln_success_cnt               NUMBER := 0;
        ln_err_cnt                   NUMBER := 0;
        --V_LINE_COUNT                 NUMBER := 0;
        lc_err_tolerance_exceeded    VARCHAR2 (100);
        ln_application_id            NUMBER;
        ln_resp_id                   NUMBER;
        ln_user_id                   NUMBER;
        lc_return_status             VARCHAR2 (50);
        lc_profile_val               VARCHAR2 (100);
        ln_request_id                NUMBER;
        ln_batch_id                  NUMBER;
        ln_head_cnt                  NUMBER := 0;
        ln_org_id                    NUMBER := NULL;
    BEGIN
        gc_code_pointer   := 'Generating PO Batch sequence :';
        debug_log (gc_code_pointer);

        BEGIN
            SELECT PO_CONTROL_GROUPS_S.NEXTVAL INTO ln_batch_id FROM DUAL;
        END;

        gc_code_pointer   := 'Batch Sequence generated as  :' || ln_batch_id;
        debug_log (gc_code_pointer);

        gc_code_pointer   := 'Derive Org ID :';
        debug_log (gc_code_pointer);

        OPEN get_macau_org;

        FETCH get_macau_org INTO ln_org_id;

        IF get_macau_org%NOTFOUND
        THEN
            ln_org_id   := NULL;
        END IF;

        CLOSE get_macau_org;

        gc_code_pointer   := 'Start inserting data into interface tables';
        debug_log (gc_code_pointer);

        FOR rec_get_distinct_po IN get_distinct_po_c
        LOOP
            ln_head_cnt   := 1;

            FOR rec_po_interface
                IN po_headers_interface_c (rec_get_distinct_po.po_number)
            LOOP
                IF ln_head_cnt = 1
                THEN
                    INSERT INTO po_headers_interface (action, process_code, DOCUMENT_NUM, BATCH_ID, document_type_code, interface_header_id, created_by, document_subtype, agent_id, creation_date, vendor_id, vendor_site_id, currency_code, rate_type, rate_date, rate, pcard_id, group_code, ORG_ID, ship_to_location_id, bill_to_location_id, ATTRIBUTE_CATEGORY, ATTRIBUTE1, ATTRIBUTE2, ATTRIBUTE3, ATTRIBUTE4, ATTRIBUTE5, ATTRIBUTE6, ATTRIBUTE7, ATTRIBUTE8, ATTRIBUTE9, ATTRIBUTE10, ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14
                                                      , ATTRIBUTE15)
                         VALUES ('ORIGINAL', NULL, rec_po_interface.po_number, ln_batch_id, 'STANDARD', po_headers_interface_s.NEXTVAL, fnd_profile.VALUE ('USER_ID'), rec_po_interface.type_lookup_code, rec_po_interface.agent_id, rec_po_interface.PO_CREATION_DATE, rec_po_interface.vendor_id, rec_po_interface.vendor_site_id, rec_po_interface.currency_code, rec_po_interface.rate_type, rec_po_interface.rate_date, rec_po_interface.rate, rec_po_interface.pcard_id, rec_po_interface.group_code, rec_po_interface.ORG_ID, rec_po_interface.ship_to_location_id, rec_po_interface.bill_to_location_id, rec_po_interface.ATTRIBUTE_CATEGORY, rec_po_interface.HEADER_ATTRIBUTE1, rec_po_interface.HEADER_ATTRIBUTE2, rec_po_interface.HEADER_ATTRIBUTE3, rec_po_interface.HEADER_ATTRIBUTE4, rec_po_interface.HEADER_ATTRIBUTE5, rec_po_interface.HEADER_ATTRIBUTE6, rec_po_interface.HEADER_ATTRIBUTE7, rec_po_interface.HEADER_ATTRIBUTE8, rec_po_interface.HEADER_ATTRIBUTE9, rec_po_interface.HEADER_ATTRIBUTE10, rec_po_interface.HEADER_ATTRIBUTE11, rec_po_interface.HEADER_ATTRIBUTE12, rec_po_interface.HEADER_ATTRIBUTE13, rec_po_interface.HEADER_ATTRIBUTE14
                                 , rec_po_interface.ATTRIBUTE15);
                END IF;


                ln_head_cnt   := ln_head_cnt + 1;

                INSERT INTO po_lines_interface (
                                action,
                                interface_line_id,
                                interface_header_id,
                                unit_price,
                                line_num,               --Added on 12-MAY-2015
                                shipment_num,               --added on 19thmay
                                quantity,
                                item_id,
                                item_description,
                                unit_OF_MEASURE,
                                category_id,
                                job_id,
                                need_by_date,
                                PROMISED_DATE,
                                line_type_id,
                                --                                         vendor_product_num,
                                ip_category_id,
                                requisition_line_id,
                                ship_to_organization_id,
                                SHIP_TO_LOCATION_ID,
                                note_to_receiver,
                                --shipment_attribute4,
                                --shipment_attribute10,
                                shipment_attribute_CATEGORY,
                                LINE_ATTRIBUTE_CATEGORY_lines,
                                LINE_ATTRIBUTE1,
                                LINE_ATTRIBUTE2,
                                LINE_ATTRIBUTE7,
                                LINE_ATTRIBUTE14,
                                LINE_ATTRIBUTE15,
                                LINE_attribute3,
                                LINE_attribute5,
                                LINE_attribute6,
                                LINE_attribute8,
                                LINE_attribute9,
                                LINE_attribute10,
                                LINE_attribute11,
                                LINE_attribute12,
                                LINE_attribute13,
                                SHIPMENT_attribute1,
                                SHIPMENT_attribute2,
                                SHIPMENT_attribute3,
                                SHIPMENT_attribute4,
                                SHIPMENT_attribute5,
                                SHIPMENT_attribute6,
                                SHIPMENT_attribute7,
                                SHIPMENT_attribute8,
                                SHIPMENT_attribute9,
                                SHIPMENT_attribute10,
                                SHIPMENT_attribute11,
                                SHIPMENT_attribute12,
                                SHIPMENT_attribute13,
                                SHIPMENT_attribute14,
                                SHIPMENT_attribute15)
                         VALUES (
                                    'ORIGINAL',
                                    po_lines_interface_s.NEXTVAL,
                                    po_headers_interface_s.CURRVAL,
                                    rec_po_interface.unit_price,
                                    rec_po_interface.po_line_num, --Added on 12-MAY-2015
                                    rec_po_interface.shipment_num, --added on 19thmay
                                    rec_po_interface.quantity,
                                    rec_po_interface.item_id,
                                    rec_po_interface.item_description,
                                    rec_po_interface.unit_meas_lookup_code,
                                    rec_po_interface.category_id,
                                    rec_po_interface.job_id,
                                    rec_po_interface.need_by_date,
                                    rec_po_interface.PROMISED_DATE,
                                    rec_po_interface.line_type_id,
                                    NULL,
                                    rec_po_interface.requisition_line_id,
                                    rec_po_interface.ship_to_organization_id,
                                    rec_po_interface.SHIP_TO_LOCATION_ID,
                                    rec_po_interface.note_to_receiver,
                                    --rec_po_interface.shipment_attribute4,
                                    --rec_po_interface.shipment_attribute10,
                                    rec_po_interface.shipment_attribute_CATEGORY,
                                    rec_po_interface.line_attribute_category,
                                    rec_po_interface.line_attribute1,
                                    rec_po_interface.line_attribute2,
                                    rec_po_interface.line_attribute7,
                                    rec_po_interface.line_attribute14,
                                    rec_po_interface.line_attribute15,
                                    rec_po_interface.line_attribute3,
                                    rec_po_interface.line_attribute5,
                                    rec_po_interface.line_attribute6,
                                    rec_po_interface.line_attribute8,
                                    rec_po_interface.line_attribute9,
                                    rec_po_interface.line_attribute10,
                                    rec_po_interface.line_attribute11,
                                    rec_po_interface.line_attribute12,
                                    rec_po_interface.line_attribute13,
                                    --rec_po_interface.LINE_attribute14,
                                    --rec_po_interface.LINE_attribute15,
                                    rec_po_interface.shipment_attribute1,
                                    rec_po_interface.shipment_attribute2,
                                    rec_po_interface.shipment_attribute3,
                                    --Modified on 11-MAY-2015
                                    TO_CHAR (
                                        TO_DATE (
                                            rec_po_interface.SHIPMENT_ATTRIBUTE4,
                                            'DD-MON-YY'),
                                        'YYYY/MM/DD HH12:MI:SS'),
                                    TO_CHAR (
                                        TO_DATE (
                                            rec_po_interface.SHIPMENT_attribute5,
                                            'DD-MON-YY'),
                                        'YYYY/MM/DD HH12:MI:SS'),
                                    --rec_po_interface.SHIPMENT_attribute4,
                                    --rec_po_interface.SHIPMENT_attribute5,
                                    --Modified on 11-MAY-2015
                                    rec_po_interface.SHIPMENT_attribute6,
                                    rec_po_interface.SHIPMENT_attribute7,
                                    rec_po_interface.SHIPMENT_attribute8,
                                    rec_po_interface.SHIPMENT_attribute9,
                                    rec_po_interface.SHIPMENT_attribute10,
                                    rec_po_interface.SHIPMENT_attribute11,
                                    rec_po_interface.SHIPMENT_attribute12,
                                    rec_po_interface.SHIPMENT_attribute13,
                                    rec_po_interface.SHIPMENT_attribute14,
                                    rec_po_interface.SHIPMENT_attribute15);
            END LOOP;

            ln_head_cnt   := 0;
        END LOOP;

        gc_code_pointer   := 'Data insertion completed';
        debug_log (gc_code_pointer);

        gc_code_pointer   :=
            'Kick off Import standard Purchase Order program';
        debug_log (gc_code_pointer);
        submit_po_request (ln_batch_id, ln_org_id);
        --30-JUN-2015
        UPDATE_ORDER_ATTRIBUTE;

        --30-JUN-2015



        BEGIN
            FOR i IN Get_EDI_c
            LOOP
                UPDATE po_headers_all
                   SET EDI_PROCESSED_FLAG = i.EDI_PROCESSED_FLAG, EDI_PROCESSED_STATUS = i.EDI_PROCESSED_STATUS
                 WHERE po_header_id = i.po_header_id;
            END LOOP;
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            gc_code_pointer   :=
                'Exception occurs at Stage :' || gc_code_pointer;
            debug_log (gc_code_pointer);
            gc_code_pointer   := 'Error : ' || SQLERRM;
            debug_log (gc_code_pointer);
            x_errbuf          := gc_code_pointer;
            x_retcode         := 1;
    END xxd_autocreate_po;


    /* **************************************************************************************************
    Procedure  Name: Main procedure
    Description: This procedure creates IR / Sales Order / Purchase requisition and Purchase orders
    Parameters:
    Name                     Type          Description
    ==============           ======       =============================================
    x_retcode                IN           Return code .
    x_errbuf                 IN           Error message.
    p_process                IN           This tells whether program should create IR / Sales Order
                                          or Purchase requisition or Purchase orders

    ************************************************************************************************** */

    PROCEDURE main (x_retcode OUT NUMBER, x_errbuf OUT VARCHAR2, p_process IN VARCHAR2
                    , p_debug IN VARCHAR2)
    IS
    BEGIN
        gc_debug_flag   := 'Y';

        IF p_process = 'EXTRCAT_INTERNAL_REQ'
        THEN
            gc_code_pointer   := 'Calling get_internal_req_extract_prc()';
            debug_log (gc_code_pointer);
            get_internal_req_extract_prc (x_retcode, x_errbuf);
        ELSIF p_process = 'VAL_INTERNAL_REQ'
        THEN
            gc_code_pointer   := 'Calling validate_requisition_prc()';
            debug_log (gc_code_pointer);
            validate_requisition_prc (x_retcode, x_errbuf);
        ELSIF p_process = 'IMPORT_INTERNAL_REQ'
        THEN
            gc_code_pointer   := 'Calling import_internal_req_prc()';
            debug_log (gc_code_pointer);
            import_internal_req_prc (x_retcode, x_errbuf);
        ELSIF p_process = 'CREATE_INTERNAL_SO'
        THEN
            gc_code_pointer   := 'Calling xxd_order_import()';
            debug_log (gc_code_pointer);
            xxd_order_import (x_retcode, x_errbuf);
        ELSIF p_process = 'CREATE_PURCHAE_REQ'
        THEN
            gc_code_pointer   := 'Calling create_purchase_requisition()';
            debug_log (gc_code_pointer);
            create_purchase_requisition (x_retcode, x_errbuf);
        ELSIF p_process = 'CREATE_PURCHAE_ORDER'
        THEN
            gc_code_pointer   := 'Calling create_purchase_requisition()';
            debug_log (gc_code_pointer);
            xxd_autocreate_po (x_errbuf, x_retcode);
        END IF;
    END;
END XXD_JP_DIRECT_PO_CONV_PKG;
/
