--
-- XXD_PO_REQUISITION_CONV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:33 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_REQUISITION_CONV_PKG"
AS
    /*******************************************************************************
    * Program Name : XXD_PO_REQUISITION_CONV_PKG
    * Language     : PL/SQL
    * Description  : This package will load requisition data in to Oracle Purchasing base tables
    *
    * History      :
    *
    * WHO            WHAT              Desc                             WHEN
    * -------------- ---------------------------------------------- ---------------
    * BT Technology Team 1.0                                             01-NOV-2014
    * --------------------------------------------------------------------------- */
    gn_user_id           NUMBER := fnd_global.user_id;
    gn_resp_id           NUMBER := fnd_global.resp_id;
    gn_resp_appl_id      NUMBER := fnd_global.resp_appl_id;
    gn_req_id            NUMBER := fnd_global.conc_request_id;
    gn_sob_id            NUMBER := fnd_profile.VALUE ('GL_SET_OF_BKS_ID');
    gn_org_id            NUMBER := XXD_common_utils.get_org_id;
    gn_login_id          NUMBER := fnd_global.login_id;
    gd_sysdate           DATE := SYSDATE;
    gc_code_pointer      VARCHAR2 (500);
    gb_boolean           BOOLEAN;
    gn_inv_process       NUMBER;
    gn_inv_reject        NUMBER;
    gn_dist_processed    NUMBER;
    gn_dist_rejected     NUMBER;
    gn_hold_processed    NUMBER;
    gn_hold_rejected     NUMBER;
    gn_inv_found         NUMBER;
    gn_dist_found        NUMBER;
    gn_hold_found        NUMBER;
    gn_dist_extract      NUMBER;
    gn_hold_extract      NUMBER;
    gn_limit             NUMBER := 5000;
    gc_yesflag           VARCHAR2 (1) := 'Y';
    gc_noflag            VARCHAR2 (1) := 'N';
    gc_debug_flag        VARCHAR2 (1) := 'Y';
    gn_DISTRIBUTION_ID   NUMBER;



    /****************************************************************************************
       * Procedure : GET_NEW_ORG_ID
       * Synopsis  : This Procedure shall provide the new org_id for given 12.0 operating_unit name
       * Design    : Program input old_operating_unit_name is passed
       * Notes     :
       * Return Values: None
       * Modification :
       * Date          Developer     Version    Description
       *--------------------------------------------------------------------------------------
       * 07-JUL-2014   BT         1.00       Created
       ****************************************************************************************/
    PROCEDURE write_log (p_message IN VARCHAR2)
    -- +===================================================================+
    -- | Name  : WRITE_LOG                                                 |
    -- |                                                                   |
    -- | Description:       This Procedure shall write to the concurrent   |
    -- |                    program log file                               |
    -- +===================================================================+
    IS
    BEGIN
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG, p_message);
    END write_log;

    PROCEDURE GET_NEW_ORG_ID (p_old_org_name IN VARCHAR2, p_debug_flag IN VARCHAR2, x_NEW_ORG_ID OUT NUMBER
                              , x_new_org_name OUT VARCHAR2)
    IS
        lc_attribute2    VARCHAR2 (1000);
        lc_error_code    VARCHAR2 (1000);
        lC_error_msg     VARCHAR2 (1000);
        lc_attribute1    VARCHAR2 (1000);
        xc_meaning       VARCHAR2 (1000);
        xc_description   VARCHAR2 (1000);
        xc_lookup_code   VARCHAR2 (1000);
        ln_org_id        NUMBER;

        CURSOR org_id_c (p_org_name VARCHAR2)
        IS
            SELECT organization_id
              FROM HR_OPERATING_UNITS
             WHERE name = p_org_name;
    BEGIN
        xc_meaning       := p_old_org_name;

        --PRINT_LOG_PRC (p_debug_flag, 'p_old_org_name : ' || p_old_org_name);

        --Passing old operating unit name to fetch corresponding new operating_unit name

        XXD_COMMON_UTILS.GET_MAPPING_VALUE (
            p_lookup_type    => 'XXD_1206_OU_MAPPING',
            px_lookup_code   => xc_lookup_code,
            px_meaning       => xc_meaning,
            px_description   => xc_description,
            x_attribute1     => lc_attribute1,
            x_attribute2     => lc_attribute2,
            x_error_code     => lc_error_code,
            x_error_msg      => lc_error_msg);

        --PRINT_LOG_PRC (p_debug_flag, 'lc_attribute1 : ' || lc_attribute1);

        x_new_org_name   := lc_attribute1;

        -- Calling cursor to fetch Org_id for a given operating_unit name.

        OPEN org_id_c (lc_attribute1);

        ln_org_id        := NULL;

        FETCH org_id_c INTO ln_org_id;

        CLOSE org_id_c;

        x_NEW_ORG_ID     := ln_org_id;
    END GET_NEW_ORG_ID;



    /****************************************************************************************
          * Procedure : EXTRACT_REQUISITION_PROC
          * Synopsis  : This Procedure is called by val_load_main_prc Main procedure
          * Design    : Procedure loads data to staging table for AP Invoice Conversion
          * Notes     :
          * Return Values: None
          * Modification :
          * Date          Developer             Version    Description
          *--------------------------------------------------------------------------------------
          * 07-JUL-2014   BT Technoloy team       1.00       Created
          ****************************************************************************************/

    PROCEDURE EXTRACT_REQUISITION_PROC (p_no_of_process   IN NUMBER,
                                        p_scenario        IN VARCHAR2)
    IS
        CURSOR requisition_c IS
            SELECT /*+ FIRST_ROWS(100) */
                   AUTHORIZATION_STATUS, CATEGORY_ID, REQUISITION_HEADER_ID,
                   -- REQUISITION_LINE_ID,
                   DISTRIBUTION_ID, CATEGORY_NAME, CHARGE_ACCOUNT_ID,
                   CONCATENATED_SEGMENTS, DELIVER_TO_LOCATION_ID, DESTINATION_ORGANIZATION_ID,
                   SOURCE_ORGANIZATION_ID, DESTINATION_TYPE_CODE, INTERFACE_SOURCE_CODE,
                   ITEM_NUMBER, ITEM_DESCRIPTION, ITEM_ID,
                   LINE_TYPE, REQUISITION_LINE_ID, LINE_TYPE_ID,
                   LOCATION_CODE, NEED_BY_DATE, promised_date,
                   OPERATING_UNIT, destination_organization_name, source_organization_name,
                   requisition_type, ORG_ID, NVL (PREPARER, 'Stewart, Celene') PREPARER,
                   PREPARER_ID, QUANTITY, pol_quantity,
                   QUANTITY_RECEIVE, NVL (AGENT_NAME, 'Stewart, Celene') AGENT_NAME, --DECODE (REQUESTOR,'Schmeichel, Nathan','Bolenbaugh, Adam',REQUESTOR) REQUESTOR,
                                                                                     NVL (REQUESTOR, 'Stewart, Celene') REQUESTOR,
                   REQUISITION_NUMBER, SEGMENT1, SEGMENT2,
                   SEGMENT3, SEGMENT4, SOURCE_TYPE_CODE,
                   TO_PERSON_ID, UNIT_MEAS_LOOKUP_CODE, UNIT_PRICE,
                   po_UNIT_PRICE, line_num, PO_LINE_NUM,
                   SHIPMENT_NUM,                            --ADDED ON 19THMAY
                                 REQ_HEADER_ATTRIBUTE_CATEGORY, REQ_HEADER_ATTRIBUTE1,
                   REQ_HEADER_ATTRIBUTE2, REQ_HEADER_ATTRIBUTE3, REQ_HEADER_ATTRIBUTE4,
                   REQ_HEADER_ATTRIBUTE5, REQ_HEADER_ATTRIBUTE6, REQ_HEADER_ATTRIBUTE7,
                   REQ_HEADER_ATTRIBUTE8, REQ_HEADER_ATTRIBUTE9, REQ_HEADER_ATTRIBUTE10,
                   REQ_HEADER_ATTRIBUTE11, REQ_HEADER_ATTRIBUTE12, REQ_HEADER_ATTRIBUTE13,
                   REQ_HEADER_ATTRIBUTE14, REQ_HEADER_ATTRIBUTE15, REQ_LINE_ATTRIBUTE_CATEGORY,
                   REQ_LINE_ATTRIBUTE1, REQ_LINE_ATTRIBUTE2, REQ_LINE_ATTRIBUTE3,
                   REQ_LINE_ATTRIBUTE4, REQ_LINE_ATTRIBUTE5, REQ_LINE_ATTRIBUTE6,
                   REQ_LINE_ATTRIBUTE7, REQ_LINE_ATTRIBUTE8, REQ_LINE_ATTRIBUTE9,
                   REQ_LINE_ATTRIBUTE10, REQ_LINE_ATTRIBUTE11, REQ_LINE_ATTRIBUTE12,
                   REQ_LINE_ATTRIBUTE13, REQ_LINE_ATTRIBUTE14, REQ_LINE_ATTRIBUTE15,
                   REQ_DIST_ATTRIBUTE_CATEGORY, REQ_DIST_ATTRIBUTE1, REQ_DIST_ATTRIBUTE2,
                   REQ_DIST_ATTRIBUTE3, REQ_DIST_ATTRIBUTE4, REQ_DIST_ATTRIBUTE5,
                   REQ_DIST_ATTRIBUTE6, REQ_DIST_ATTRIBUTE7, REQ_DIST_ATTRIBUTE8,
                   REQ_DIST_ATTRIBUTE9, REQ_DIST_ATTRIBUTE10, REQ_DIST_ATTRIBUTE11,
                   REQ_DIST_ATTRIBUTE12, REQ_DIST_ATTRIBUTE13, REQ_DIST_ATTRIBUTE14,
                   REQ_DIST_ATTRIBUTE15, header_attribute_category, header_attribute1,
                   header_attribute2, header_attribute3, header_attribute4,
                   header_attribute5, header_attribute6, header_attribute7,
                   header_attribute8, header_attribute9, header_attribute10,
                   header_attribute11, header_attribute12, header_attribute13,
                   header_attribute14, header_attribute15, line_attribute_category,
                   line_attribute1, line_attribute2, line_attribute3,
                   line_attribute4, line_attribute5, line_attribute6,
                   line_attribute7, line_attribute8, line_attribute9,
                   line_attribute10, line_attribute11, line_attribute12,
                   line_attribute13, line_attribute14, line_attribute15,
                   SHIPMENT_ATTRIBUTE_CATEGORY, SHIPMENT_ATTRIBUTE1, SHIPMENT_ATTRIBUTE2,
                   SHIPMENT_ATTRIBUTE3, SHIPMENT_ATTRIBUTE4, SHIPMENT_ATTRIBUTE5,
                   SHIPMENT_ATTRIBUTE6, SHIPMENT_ATTRIBUTE7, SHIPMENT_ATTRIBUTE8,
                   SHIPMENT_ATTRIBUTE9, SHIPMENT_ATTRIBUTE10, SHIPMENT_ATTRIBUTE11,
                   SHIPMENT_ATTRIBUTE12, SHIPMENT_ATTRIBUTE13, SHIPMENT_ATTRIBUTE14,
                   SHIPMENT_ATTRIBUTE15, dist_attribute_category, dist_attribute1,
                   dist_attribute2, dist_attribute3, dist_attribute4,
                   dist_attribute5, dist_attribute6, dist_attribute7,
                   dist_attribute8, dist_attribute9, dist_attribute10,
                   dist_attribute11, dist_attribute12, dist_attribute13,
                   dist_attribute14, dist_attribute15, DESTINATION_SUBINVENTORY, --Added on 11-MAY-2015
                   DIST_QUANTITY,                       --Added on 11-MAY-2015
                                  SCENARIO, vendor_name,
                   --vendor_id,
                   vendor_site_code, ORDER_NUMBER, --vendor_site_id,
                                                   NTILE (p_no_of_process) OVER (ORDER BY REQUISITION_HEADER_ID) worker_batch_number,
                   po_number, purchase_req_number, po_header_id,
                   po_line_id, IR_creation_date, ISO_creation_date,
                   PR_creation_date, PO_creation_date, EDI_PROCESSED_FLAG,
                   EDI_PROCESSED_STATUS
              FROM xxd_conv.XXD_1206_PO_REQ_T     --xxd_conv.XXD_1206_PO_REQ_T
             WHERE     1 = 1
                   AND SCENARIO = NVL (p_scenario, SCENARIO)
                   AND po_number <> '62624'; --AND REQUISITION_HEADER_ID = 165723
              --AND REQUISITION_NUMBER IN ('62191')               --, '60133')
 /*   AND REQUISITION_NUMBER IN ('60654',
                                 '60441',
                                 '60133',
                                 '61217',
                                 '62191'
                                 ) */



        TYPE xxd_requisition_tab IS TABLE OF requisition_c%ROWTYPE
            INDEX BY BINARY_INTEGER;

        gtt_req_int_tab        XXD_requisition_tab;

        ln_loop_counter        NUMBER;
        gn_inv_extract         NUMBER;

        CURSOR get_req_header_c IS
            SELECT OLD_REQUISITION_HEADER_ID
              FROM XXD_PO_REQUISITION_CONV_STG_T
             WHERE SCENARIO = NVL (p_scenario, SCENARIO);

        lcu_get_req_header_c   get_req_header_c%ROWTYPE;
    BEGIN
        gc_code_pointer   := 'Deleting data from  Staging table';

        --Deleting data from  Header and line staging table

        /* EXECUTE IMMEDIATE
            'truncate table XXD_CONV.XXD_PO_REQUISITION_CONV_STG_T'; */
        --commented on 28thmay

        DELETE FROM XXD_CONV.XXD_PO_REQUISITION_CONV_STG_T
              WHERE SCENARIO = NVL (p_scenario, SCENARIO);

        gc_code_pointer   := 'Insert into   staging table';

        -- Insert records into Invoice  staging table



        OPEN requisition_c;

        ln_loop_counter   := 0;

        LOOP
            FETCH requisition_c
                BULK COLLECT INTO gtt_req_int_tab
                LIMIT gn_limit;

            IF gtt_req_int_tab.COUNT > 0
            THEN
                BEGIN
                    FORALL i IN 1 .. gtt_req_int_tab.COUNT SAVE EXCEPTIONS
                        INSERT INTO XXD_PO_REQUISITION_CONV_STG_T (
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
                                        pol_QUANTITY,
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
                                        po_UNIT_PRICE,
                                        line_num,
                                        PO_LINE_NUM,
                                        SHIPMENT_NUM,       --ADDED ON 19THMAY
                                        vendor_name,
                                        --vendor_id,
                                        vendor_site_code,
                                        ORDER_NUMBER,
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
                                        DESTINATION_SUBINVENTORY,
                                        DIST_QUANTITY,
                                        SCENARIO,
                                        record_status,
                                        LAST_UPDATE_DATE,
                                        LAST_UPDATED_BY,
                                        LAST_UPDATED_LOGIN,
                                        CREATION_DATE,
                                        CREATED_BY,
                                        request_id,
                                        worker_batch_number,
                                        po_number,
                                        purchase_req_number,
                                        po_header_id,
                                        po_line_id,
                                        IR_creation_date,
                                        ISO_creation_date,
                                        PR_creation_date,
                                        PO_creation_date,
                                        EDI_PROCESSED_FLAG,
                                        EDI_PROCESSED_STATUS)
                                 VALUES (
                                            gtt_req_int_tab (i).AUTHORIZATION_STATUS,
                                            gtt_req_int_tab (i).CATEGORY_ID,
                                            gtt_req_int_tab (i).requisition_type,
                                            gtt_req_int_tab (i).REQUISITION_HEADER_ID,
                                            gtt_req_int_tab (i).REQUISITION_LINE_ID,
                                            --gtt_req_int_tab (i).REQUISITION_LINE_ID,
                                            gtt_req_int_tab (i).DISTRIBUTION_ID,
                                            gtt_req_int_tab (i).CATEGORY_NAME,
                                            gtt_req_int_tab (i).CHARGE_ACCOUNT_ID,
                                            gtt_req_int_tab (i).CONCATENATED_SEGMENTS,
                                            gtt_req_int_tab (i).DELIVER_TO_LOCATION_ID,
                                            gtt_req_int_tab (i).DESTINATION_ORGANIZATION_ID,
                                            gtt_req_int_tab (i).SOURCE_ORGANIZATION_ID,
                                            gtt_req_int_tab (i).DESTINATION_TYPE_CODE,
                                            gtt_req_int_tab (i).INTERFACE_SOURCE_CODE,
                                            gtt_req_int_tab (i).ITEM_NUMBER,
                                            gtt_req_int_tab (i).ITEM_DESCRIPTION,
                                            gtt_req_int_tab (i).ITEM_ID,
                                            gtt_req_int_tab (i).LINE_TYPE,
                                            gtt_req_int_tab (i).LINE_TYPE_ID,
                                            gtt_req_int_tab (i).LOCATION_CODE,
                                            gtt_req_int_tab (i).NEED_BY_DATE,
                                            gtt_req_int_tab (i).promised_date,
                                            gtt_req_int_tab (i).OPERATING_UNIT,
                                            gtt_req_int_tab (i).destination_organization_name,
                                            gtt_req_int_tab (i).source_organization_name,
                                            gtt_req_int_tab (i).ORG_ID,
                                            gtt_req_int_tab (i).PREPARER,
                                            gtt_req_int_tab (i).PREPARER_ID,
                                            gtt_req_int_tab (i).QUANTITY,
                                            gtt_req_int_tab (i).pol_QUANTITY,
                                            gtt_req_int_tab (i).QUANTITY_RECEIVE,
                                            gtt_req_int_tab (i).AGENT_NAME,
                                            gtt_req_int_tab (i).REQUESTOR,
                                            gtt_req_int_tab (i).REQUISITION_NUMBER,
                                            gtt_req_int_tab (i).SEGMENT1,
                                            gtt_req_int_tab (i).SEGMENT2,
                                            gtt_req_int_tab (i).SEGMENT3,
                                            gtt_req_int_tab (i).SEGMENT4,
                                            gtt_req_int_tab (i).SOURCE_TYPE_CODE,
                                            gtt_req_int_tab (i).TO_PERSON_ID,
                                            gtt_req_int_tab (i).UNIT_MEAS_LOOKUP_CODE,
                                            gtt_req_int_tab (i).UNIT_PRICE,
                                            gtt_req_int_tab (i).po_UNIT_PRICE,
                                            gtt_req_int_tab (i).line_num,
                                            gtt_req_int_tab (i).PO_line_num,
                                            gtt_req_int_tab (i).SHIPMENT_NUM, --ADDED ON 19THMAY
                                            gtt_req_int_tab (i).vendor_name,
                                            --gtt_req_int_tab (i).vendor_id,
                                            gtt_req_int_tab (i).vendor_site_code,
                                            gtt_req_int_tab (i).ORDER_NUMBER,
                                            --gtt_req_int_tab (i).vendor_site_id,
                                            gtt_req_int_tab (i).REQ_HEADER_ATTRIBUTE_CATEGORY,
                                            gtt_req_int_tab (i).REQ_HEADER_ATTRIBUTE1,
                                            gtt_req_int_tab (i).REQ_HEADER_ATTRIBUTE2,
                                            gtt_req_int_tab (i).REQ_HEADER_ATTRIBUTE3,
                                            gtt_req_int_tab (i).REQ_HEADER_ATTRIBUTE4,
                                            gtt_req_int_tab (i).REQ_HEADER_ATTRIBUTE5,
                                            gtt_req_int_tab (i).REQ_HEADER_ATTRIBUTE6,
                                            gtt_req_int_tab (i).REQ_HEADER_ATTRIBUTE7,
                                            gtt_req_int_tab (i).REQ_HEADER_ATTRIBUTE8,
                                            gtt_req_int_tab (i).REQ_HEADER_ATTRIBUTE9,
                                            gtt_req_int_tab (i).REQ_HEADER_ATTRIBUTE10,
                                            gtt_req_int_tab (i).REQ_HEADER_ATTRIBUTE11,
                                            gtt_req_int_tab (i).REQ_HEADER_ATTRIBUTE12,
                                            gtt_req_int_tab (i).REQ_HEADER_ATTRIBUTE13,
                                            gtt_req_int_tab (i).REQ_HEADER_ATTRIBUTE14,
                                            gtt_req_int_tab (i).REQ_HEADER_ATTRIBUTE15,
                                            gtt_req_int_tab (i).REQ_LINE_ATTRIBUTE_CATEGORY,
                                            gtt_req_int_tab (i).REQ_LINE_ATTRIBUTE1,
                                            gtt_req_int_tab (i).REQ_LINE_ATTRIBUTE2,
                                            gtt_req_int_tab (i).REQ_LINE_ATTRIBUTE3,
                                            gtt_req_int_tab (i).REQ_LINE_ATTRIBUTE4,
                                            gtt_req_int_tab (i).REQ_LINE_ATTRIBUTE5,
                                            gtt_req_int_tab (i).REQ_LINE_ATTRIBUTE6,
                                            gtt_req_int_tab (i).REQ_LINE_ATTRIBUTE7,
                                            gtt_req_int_tab (i).REQ_LINE_ATTRIBUTE8,
                                            gtt_req_int_tab (i).REQ_LINE_ATTRIBUTE9,
                                            gtt_req_int_tab (i).REQ_LINE_ATTRIBUTE10,
                                            gtt_req_int_tab (i).REQ_LINE_ATTRIBUTE11,
                                            gtt_req_int_tab (i).REQ_LINE_ATTRIBUTE12,
                                            gtt_req_int_tab (i).REQ_LINE_ATTRIBUTE13,
                                            gtt_req_int_tab (i).REQ_LINE_ATTRIBUTE14,
                                            gtt_req_int_tab (i).REQ_LINE_ATTRIBUTE15,
                                            gtt_req_int_tab (i).REQ_DIST_ATTRIBUTE_CATEGORY,
                                            gtt_req_int_tab (i).REQ_DIST_ATTRIBUTE1,
                                            gtt_req_int_tab (i).REQ_DIST_ATTRIBUTE2,
                                            gtt_req_int_tab (i).REQ_DIST_ATTRIBUTE3,
                                            gtt_req_int_tab (i).REQ_DIST_ATTRIBUTE4,
                                            gtt_req_int_tab (i).REQ_DIST_ATTRIBUTE5,
                                            gtt_req_int_tab (i).REQ_DIST_ATTRIBUTE6,
                                            gtt_req_int_tab (i).REQ_DIST_ATTRIBUTE7,
                                            gtt_req_int_tab (i).REQ_DIST_ATTRIBUTE8,
                                            gtt_req_int_tab (i).REQ_DIST_ATTRIBUTE9,
                                            gtt_req_int_tab (i).REQ_DIST_ATTRIBUTE10,
                                            gtt_req_int_tab (i).REQ_DIST_ATTRIBUTE11,
                                            gtt_req_int_tab (i).REQ_DIST_ATTRIBUTE12,
                                            gtt_req_int_tab (i).REQ_DIST_ATTRIBUTE13,
                                            gtt_req_int_tab (i).REQ_DIST_ATTRIBUTE14,
                                            gtt_req_int_tab (i).REQ_DIST_ATTRIBUTE15,
                                            gtt_req_int_tab (i).header_attribute_category,
                                            gtt_req_int_tab (i).header_attribute1,
                                            gtt_req_int_tab (i).header_attribute2,
                                            gtt_req_int_tab (i).header_attribute3,
                                            gtt_req_int_tab (i).header_attribute4,
                                            gtt_req_int_tab (i).header_attribute5,
                                            gtt_req_int_tab (i).header_attribute6,
                                            gtt_req_int_tab (i).header_attribute7,
                                            gtt_req_int_tab (i).header_attribute8,
                                            gtt_req_int_tab (i).header_attribute9,
                                            gtt_req_int_tab (i).header_attribute10,
                                            gtt_req_int_tab (i).header_attribute11,
                                            gtt_req_int_tab (i).header_attribute12,
                                            gtt_req_int_tab (i).header_attribute13,
                                            gtt_req_int_tab (i).header_attribute14,
                                            gtt_req_int_tab (i).header_attribute15,
                                            gtt_req_int_tab (i).line_attribute_category,
                                            gtt_req_int_tab (i).line_attribute1,
                                            gtt_req_int_tab (i).line_attribute2,
                                            gtt_req_int_tab (i).line_attribute3,
                                            gtt_req_int_tab (i).line_attribute4,
                                            gtt_req_int_tab (i).line_attribute5,
                                            gtt_req_int_tab (i).line_attribute6,
                                            gtt_req_int_tab (i).line_attribute7,
                                            gtt_req_int_tab (i).line_attribute8,
                                            gtt_req_int_tab (i).line_attribute9,
                                            gtt_req_int_tab (i).line_attribute10,
                                            gtt_req_int_tab (i).line_attribute11,
                                            gtt_req_int_tab (i).line_attribute12,
                                            gtt_req_int_tab (i).line_attribute13,
                                            gtt_req_int_tab (i).line_attribute14,
                                            gtt_req_int_tab (i).line_attribute15,
                                            -- gtt_req_int_tab (i).REQUISITION_LINE_ID,
                                            gtt_req_int_tab (i).SHIPMENT_ATTRIBUTE_category,
                                            gtt_req_int_tab (i).SHIPMENT_ATTRIBUTE1,
                                            gtt_req_int_tab (i).SHIPMENT_ATTRIBUTE2,
                                            gtt_req_int_tab (i).SHIPMENT_ATTRIBUTE3,
                                            gtt_req_int_tab (i).SHIPMENT_ATTRIBUTE4,
                                            gtt_req_int_tab (i).SHIPMENT_ATTRIBUTE5,
                                            gtt_req_int_tab (i).SHIPMENT_ATTRIBUTE6,
                                            gtt_req_int_tab (i).SHIPMENT_ATTRIBUTE7,
                                            gtt_req_int_tab (i).SHIPMENT_ATTRIBUTE8,
                                            gtt_req_int_tab (i).SHIPMENT_ATTRIBUTE9,
                                            gtt_req_int_tab (i).SHIPMENT_ATTRIBUTE10,
                                            gtt_req_int_tab (i).SHIPMENT_ATTRIBUTE11,
                                            gtt_req_int_tab (i).SHIPMENT_ATTRIBUTE12,
                                            gtt_req_int_tab (i).SHIPMENT_ATTRIBUTE13,
                                            gtt_req_int_tab (i).SHIPMENT_ATTRIBUTE14,
                                            gtt_req_int_tab (i).SHIPMENT_ATTRIBUTE15,
                                            gtt_req_int_tab (i).dist_attribute_category,
                                            gtt_req_int_tab (i).dist_attribute1,
                                            gtt_req_int_tab (i).dist_attribute2,
                                            gtt_req_int_tab (i).dist_attribute3,
                                            gtt_req_int_tab (i).dist_attribute4,
                                            gtt_req_int_tab (i).dist_attribute5,
                                            gtt_req_int_tab (i).dist_attribute6,
                                            gtt_req_int_tab (i).dist_attribute7,
                                            gtt_req_int_tab (i).dist_attribute8,
                                            gtt_req_int_tab (i).dist_attribute9,
                                            gtt_req_int_tab (i).dist_attribute10,
                                            gtt_req_int_tab (i).dist_attribute11,
                                            gtt_req_int_tab (i).dist_attribute12,
                                            gtt_req_int_tab (i).dist_attribute13,
                                            gtt_req_int_tab (i).dist_attribute14,
                                            gtt_req_int_tab (i).dist_attribute15,
                                            gtt_req_int_tab (i).DESTINATION_SUBINVENTORY, --Modifed on 11-MAY-2015
                                            gtt_req_int_tab (i).DIST_QUANTITY,
                                            gtt_req_int_tab (i).SCENARIO,
                                            'N',
                                            gd_sysdate,
                                            gn_user_id,
                                            gn_login_id,
                                            gd_sysdate,
                                            gn_user_id,
                                            gn_req_id,
                                            gtt_req_int_tab (i).worker_batch_number,
                                            gtt_req_int_tab (i).po_number,
                                            gtt_req_int_tab (i).purchase_req_number,
                                            gtt_req_int_tab (i).po_header_id,
                                            gtt_req_int_tab (i).po_line_id,
                                            gtt_req_int_tab (i).IR_creation_date,
                                            gtt_req_int_tab (i).ISO_creation_date,
                                            gtt_req_int_tab (i).PR_creation_date,
                                            gtt_req_int_tab (i).PO_creation_date,
                                            gtt_req_int_tab (i).EDI_PROCESSED_FLAG,
                                            gtt_req_int_tab (i).EDI_PROCESSED_STATUS);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        IF SQLCODE = -24381
                        THEN
                            gc_code_pointer   :=
                                'Exception while extracing data';

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
                                    'XXD_PO_REQUISITION_CONV_STG_T');
                            END LOOP;
                        ELSE
                            XXD_common_utils.record_error (
                                'PORQE',
                                gn_org_id,
                                'Deckers PO Requisition Conversion',
                                'Error in EXTRACT_REQUISITION_PROC procedure',
                                DBMS_UTILITY.format_error_backtrace,
                                gn_user_id,
                                gn_req_id,
                                'Code pointer : ' || gc_code_pointer,
                                'XXD_PO_REQUISITION_CONV_STG_T');
                        END IF;
                END;
            ELSE
                EXIT;
            END IF;

            gtt_req_int_tab.delete;

            COMMIT;
        END LOOP;

        CLOSE requisition_c;



        COMMIT;


        /*      OPEN get_req_header_c;

              LOOP
                 FETCH get_req_header_c INTO ln_requisition_header_id;

                 EXIT WHEN get_req_header_c%NOTFOUND;

                 UPDATE XXD_PO_REQUISITION_CONV_STG_T
                    SET worker_batch_number =
                           (SELECT worker_batch_number
                              FROM XXD_PO_REQUISITION_CONV_STG_T
                             WHERE     old_requisition_header_id =
                                          ln_requisition_header_id
                                   AND ROWNUM = 1)
                  WHERE old_requisition_header_id = ln_requisition_header_id;
              END LOOP;

              COMMIT;

              CLOSE get_req_header_c; */

        gc_code_pointer   := 'After insert into Staging table';

        SELECT COUNT (*)
          INTO gn_inv_extract
          FROM XXD_PO_REQUISITION_CONV_STG_T
         WHERE record_status = 'N' AND SCENARIO = NVL (p_scenario, SCENARIO);

        -- Writing counts to output file
        fnd_file.put_line (
            fnd_file.output,
            'S.No                   Entity           Total Records Extracted from 12.0.6 and loaded to 12.2.3 ');
        fnd_file.put_line (
            fnd_file.output,
            '----------------------------------------------------------------------------------------------');
        fnd_file.put_line (
            fnd_file.output,
               '1                    '
            || RPAD ('XXD_PO_REQUISITION_CONV_STG_T', 40, ' ')
            || '   '
            || gn_inv_extract);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'OTHERS Exception while Insert into XXD_PO_REQUISITION_CONV_STG_T Table');


            XXD_common_utils.record_error (
                'PORQE',
                gn_org_id,
                'Deckers PO Requisition Conversion',
                DBMS_UTILITY.format_error_backtrace,
                gn_user_id,
                gn_req_id,
                'Code pointer : ' || gc_code_pointer,
                'XXD_PO_REQUISITION_CONV_STG_T');
    END EXTRACT_REQUISITION_PROC;



    /******************************************************
       * Procedure: VALIDATE_REQUISITION_PROC
       *
       * Synopsis: This procedure will validate the records in stging table
       * Design:
       *
       * Notes:
       *
       *
       * Return Values:
       * Modifications:
       *
       ******************************************************/

    PROCEDURE VALIDATE_REQUISITION_PROC (x_retcode       OUT NUMBER,
                                         x_errbuff       OUT VARCHAR2,
                                         p_batch_no   IN     NUMBER,
                                         p_debug      IN     VARCHAR2,
                                         p_scenario   IN     VARCHAR2)
    IS
        CURSOR requisition_val_c IS
            SELECT AUTHORIZATION_STATUS, CATEGORY_ID, DISTRIBUTION_ID,
                   CATEGORY_NAME, CHARGE_ACCOUNT_ID, CONCATENATED_SEGMENTS,
                   DELIVER_TO_LOCATION_ID, DESTINATION_ORGANIZATION_ID, DESTINATION_TYPE_CODE,
                   INTERFACE_SOURCE_CODE, ITEM_NUMBER, ITEM_DESCRIPTION,
                   ITEM_ID, LINE_TYPE, LINE_TYPE_ID,
                   LOCATION_CODE, NEED_BY_DATE, OPERATING_UNIT,
                   destination_organization_name, source_organization_name, source_organization_id,
                   ORG_ID, PREPARER, PREPARER_ID,
                   agent_name, QUANTITY, REQUESTOR,
                   REQUISITION_NUMBER, SEGMENT1, SEGMENT2,
                   SEGMENT3, SEGMENT4, SOURCE_TYPE_CODE,
                   TO_PERSON_ID, UNIT_MEAS_LOOKUP_CODE, UNIT_PRICE,
                   line_num, old_requisition_header_id, vendor_name,
                   vendor_site_code, SCENARIO, PO_NUMBER
              FROM XXD_PO_REQUISITION_CONV_STG_T
             WHERE     record_status IN ('N', 'E')
                   AND WORKER_BATCH_NUMBER = p_batch_no --AND   OLD_REQUISITION_HEADER_ID = 114123 and DISTRIBUTION_ID = 1097222
                   AND SCENARIO = NVL (p_scenario, SCENARIO);



        TYPE xxd_requisition_val_tab IS TABLE OF requisition_val_c%ROWTYPE
            INDEX BY BINARY_INTEGER;

        gtt_req_val_int_tab             xxd_requisition_val_tab;

        CURSOR get_preparer_id_c (p_preparer VARCHAR2)
        IS
            SELECT person_id preparer_id
              FROM per_people_f ppf, po_agents pa
             WHERE     full_name = p_preparer
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

        ln_preparer_id                  NUMBER;



        CURSOR get_requestor_id_c (p_requestor VARCHAR2)
        IS
            SELECT person_id requestor_id
              FROM per_people_f ppf, po_agents pa
             WHERE     full_name = p_requestor
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (effective_start_date,
                                                        SYSDATE))
                                           AND TRUNC (
                                                   NVL (effective_end_date,
                                                        SYSDATE));

        ln_requestor_id                 NUMBER;

        CURSOR get_agent_id_c (p_agent VARCHAR2)
        IS
            SELECT person_id agent_id
              FROM per_people_f ppf, po_agents pa
             WHERE     full_name = p_agent
                   AND ppf.person_id = pa.agent_id
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (start_date_active,
                                                        SYSDATE))
                                           AND TRUNC (
                                                   NVL (end_date_active,
                                                        SYSDATE))
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (effective_start_date,
                                                        SYSDATE))
                                           AND TRUNC (
                                                   NVL (effective_end_date,
                                                        SYSDATE));

        ln_agent_id                     NUMBER;


        CURSOR get_uom_c (p_uom VARCHAR2)
        IS
            SELECT UNIT_OF_MEASURE
              FROM MTL_UNITS_OF_MEASURE_TL
             WHERE UNIT_OF_MEASURE = p_uom AND LANGUAGE = USERENV ('LANG');

        lc_uom                          VARCHAR2 (100);



        CURSOR get_val_item_c (p_item VARCHAR2)
        IS
            SELECT inventory_item_id, DESCRIPTION
              FROM mtl_system_items_b
             WHERE     segment1 = p_item
                   AND INVENTORY_ITEM_STATUS_CODE = 'Active';

        ln_inventory_item_id            NUMBER;
        lc_DESCRIPTION                  VARCHAR2 (240);
        l_po_num                        VARCHAR2 (240);

        CURSOR get_val_item_cnt_c (p_item_id NUMBER, p_S_ORGANIZATION_ID NUMBER, p_D_ORGANIZATION_ID NUMBER)
        IS
            SELECT COUNT (1)
              FROM mtl_system_items_b
             WHERE     inventory_item_id = p_item_id
                   AND ORGANIZATION_ID IN
                           (p_S_ORGANIZATION_ID, p_D_ORGANIZATION_ID);

        ln_count                        NUMBER;



        lc_recvalidation                VARCHAR2 (1);
        LC_H_ERR_MSG                    VARCHAR2 (1000);



        CURSOR get_code_comb_id_c (p_conc_segments VARCHAR2)
        IS
            SELECT MAX (code_combination_id)
              FROM gl_code_combinations
             WHERE    segment1
                   || '.'
                   || segment2
                   || '.'
                   || segment3
                   || '.'
                   || segment4
                   || '.'
                   || segment5
                   || '.'
                   || segment6
                   || '.'
                   || segment7
                   || '.'
                   || segment8 =
                   p_conc_segments;

        ln_ccid                         NUMBER;

        CURSOR get_coa_id_c (p_org_id NUMBER)
        IS
            SELECT chart_of_accounts_id
              FROM gl_sets_of_books gsob, hr_operating_units hou
             WHERE     hou.set_of_books_id = gsob.set_of_books_id
                   AND hou.organization_id = p_org_id;


        ln_coa_id                       NUMBER;

        CURSOR get_line_type_id_c (p_line_type VARCHAR2)
        IS
            SELECT line_type_id
              FROM po_line_types
             WHERE line_type = p_line_type;

        ln_line_type_id                 NUMBER;



        CURSOR get_location_id_c (             --p_location_code      VARCHAR2
                                  p_ORGANIZATION_ID NUMBER)
        IS
            SELECT LOCATION_ID
              FROM HR_LOCATIONS_ALL
             WHERE 1 = 1                 --AND location_code = p_location_code
                         AND INVENTORY_ORGANIZATION_ID = p_ORGANIZATION_ID;

        ln_LOCATION_ID                  NUMBER;


        CURSOR get_organization_id_c (p_ORGANIZATION_CODE VARCHAR2)
        IS
            SELECT organization_id
              FROM org_organization_definitions
             WHERE ORGANIZATION_CODE = p_ORGANIZATION_CODE;



        ln_dest_organization_ID         NUMBER;
        ln_source_organization_ID       NUMBER;


        CURSOR get_org_id_c (p_organization_id NUMBER, p_org_id NUMBER)
        IS
            SELECT operating_unit
              FROM org_organization_definitions
             WHERE     ORGANIZATION_ID = p_organization_id
                   AND operating_unit = p_org_id;

        CURSOR Get_org_id_c1 (p_operating_unit VARCHAR2)
        IS
            SELECT organization_id
              FROM hr_operating_units
             WHERE name = p_operating_unit;



        ln_org_id1                      NUMBER;
        lc_new_conc_segs                VARCHAR2 (1000);
        ln_org_id                       NUMBER;
        lc_org_name                     VARCHAR2 (150);
        gn_inv_validate                 NUMBER;
        gn_inv_error                    NUMBER;
        lc_new_dest_organization_code   VARCHAR2 (150);
        lc_new_source_org_code          VARCHAR2 (150);



        xc_meaning                      VARCHAR2 (100);
        xc_description                  VARCHAR2 (100);
        lc_attribute2                   VARCHAR2 (100);
        lc_error_code                   VARCHAR2 (100);
        lc_error_msg                    VARCHAR2 (100);



        CURSOR Get_loc_id_c (p_loc_id NUMBER)
        IS
            SELECT location_id
              FROM po_location_Associations_all
             WHERE location_id = p_loc_id;

        ln_loc_id                       NUMBER;

        CURSOR get_vendor_id_c (p_vendor_name VARCHAR2)
        IS
            SELECT vendor_id
              FROM ap_suppliers
             WHERE vendor_name = p_vendor_name;

        ln_vendor_id                    NUMBER;


        CURSOR get_vendor_site_id_c (p_vendor_id          NUMBER,
                                     p_vendor_site_code   VARCHAR2)
        IS
            SELECT vendor_site_id
              FROM ap_supplier_sites_all, hr_operating_units hrou --added on 10-Dec-15
             WHERE     vendor_id = p_vendor_id
                   AND vendor_site_code = p_vendor_site_code
                   AND ORG_ID = hrou.ORGANIZATION_ID      --ADDED ON 10-dEC-15
                   AND HROU.NAME = 'Deckers Macau OU'     --ADDED ON 10-dEC-15
                                                     ;


        ln_vendor_site_id               NUMBER;
        ln_DISTRIBUTION_ID              NUMBER;
    BEGIN
        OPEN requisition_val_c;

        LOOP
            FETCH requisition_val_c
                BULK COLLECT INTO gtt_req_val_int_tab
                LIMIT gn_limit;

            fnd_file.put_line (fnd_file.LOG, 'Test1');

            fnd_file.put_line (fnd_file.LOG,
                               'Test3 ' || gtt_req_val_int_tab.COUNT);

            --EXIT WHEN requisition_val_c%NOTFOUND;

            IF gtt_req_val_int_tab.COUNT > 0
            THEN
                FOR i IN 1 .. gtt_req_val_int_tab.COUNT
                LOOP
                    BEGIN
                        lc_recvalidation   := 'Y';
                        lc_h_err_msg       := NULL;



                        gc_code_pointer    := 'Deriving vendor ';

                        IF gtt_req_val_int_tab (i).SCENARIO IN
                               ('EUROPE', 'APAC')
                        THEN
                            OPEN get_vendor_id_c (
                                gtt_req_val_int_tab (i).vendor_name);

                            ln_vendor_id   := NULL;

                            FETCH get_vendor_id_c INTO ln_vendor_id;

                            CLOSE get_vendor_id_c;


                            IF ln_vendor_id IS NULL
                            THEN
                                lc_recvalidation   := 'N';
                                lc_h_err_msg       :=
                                    lc_h_err_msg || ' -  Invalid vendor ';

                                --print_log_prc (p_debug, lc_h_err_msg);


                                XXD_common_utils.record_error (
                                    'PORQV',
                                    gn_org_id,
                                    'Deckers PO Requisition Conversion',
                                    'Invalid vendor ',
                                    DBMS_UTILITY.format_error_backtrace,
                                    gn_user_id,
                                    gn_req_id,
                                    gtt_req_val_int_tab (i).requisition_number,
                                    gtt_req_val_int_tab (i).line_num,
                                    'Operating unit Mapping is not defined ',
                                    gtt_req_val_int_tab (i).DISTRIBUTION_ID);
                            END IF;
                        END IF;

                        gc_code_pointer    := 'Deriving vendor site ';

                        IF gtt_req_val_int_tab (i).SCENARIO IN
                               ('EUROPE', 'APAC')
                        THEN
                            OPEN get_vendor_site_id_c (
                                ln_vendor_id,
                                gtt_req_val_int_tab (i).vendor_site_code);

                            ln_vendor_site_id   := NULL;

                            FETCH get_vendor_site_id_c INTO ln_vendor_site_id;

                            CLOSE get_vendor_site_id_c;

                            IF ln_vendor_site_id IS NULL
                            THEN
                                lc_recvalidation   := 'N';
                                lc_h_err_msg       :=
                                       lc_h_err_msg
                                    || ' -  Invalid vendor site ';

                                --print_log_prc (p_debug, lc_h_err_msg);


                                XXD_common_utils.record_error (
                                    'PORQV',
                                    gn_org_id,
                                    'Deckers PO Requisition Conversion',
                                    'Invalid vendor site  ',
                                    DBMS_UTILITY.format_error_backtrace,
                                    gn_user_id,
                                    gn_req_id,
                                    gtt_req_val_int_tab (i).requisition_number,
                                    gtt_req_val_int_tab (i).line_num,
                                    'Invalid vendor site  ',
                                    gtt_req_val_int_tab (i).DISTRIBUTION_ID);
                            END IF;
                        END IF;



                        gc_code_pointer    := 'Deriving new org';

                        -- ORG_ID Check
                        IF gtt_req_val_int_tab (i).SCENARIO = 'EUROPE'
                        THEN
                            OPEN Get_org_id_c1 (
                                gtt_req_val_int_tab (i).operating_unit);

                            ln_org_id   := NULL;

                            FETCH Get_org_id_c1 INTO ln_org_id;

                            CLOSE Get_org_id_c1;

                            IF ln_org_id IS NULL
                            THEN
                                lc_recvalidation   := 'N';
                                lc_h_err_msg       :=
                                       lc_h_err_msg
                                    || ' -  Operating unit Mapping is not defined ';

                                --print_log_prc (p_debug, lc_h_err_msg);


                                XXD_common_utils.record_error (
                                    'PORQV',
                                    gn_org_id,
                                    'Deckers PO Requisition Conversion',
                                    'Operating unit Mapping is not defined ',
                                    DBMS_UTILITY.format_error_backtrace,
                                    gn_user_id,
                                    gn_req_id,
                                    gtt_req_val_int_tab (i).requisition_number,
                                    gtt_req_val_int_tab (i).line_num,
                                    'Operating unit Mapping is not defined ',
                                    gtt_req_val_int_tab (i).DISTRIBUTION_ID);
                            END IF;
                        ELSE
                            get_new_org_id (p_old_org_name => gtt_req_val_int_tab (i).operating_unit, p_debug_flag => p_debug, x_new_org_id => ln_org_id
                                            , x_new_org_name => lc_org_name);

                            IF ln_org_id IS NULL
                            THEN
                                lc_recvalidation   := 'N';
                                lc_h_err_msg       :=
                                       lc_h_err_msg
                                    || ' -  Operating unit Mapping is not defined ';

                                --print_log_prc (p_debug, lc_h_err_msg);


                                XXD_common_utils.record_error (
                                    'PORQV',
                                    gn_org_id,
                                    'Deckers PO Requisition Conversion',
                                    'Operating unit Mapping is not defined ',
                                    DBMS_UTILITY.format_error_backtrace,
                                    gn_user_id,
                                    gn_req_id,
                                    gtt_req_val_int_tab (i).requisition_number,
                                    gtt_req_val_int_tab (i).line_num,
                                    'Operating unit Mapping is not defined ',
                                    gtt_req_val_int_tab (i).DISTRIBUTION_ID);
                            END IF;
                        END IF;

                        gc_code_pointer    := 'Validating  Preparer';

                        --Start Preparer validation
                        IF gtt_req_val_int_tab (i).PREPARER IS NOT NULL
                        THEN
                            OPEN get_preparer_id_c (
                                gtt_req_val_int_tab (i).PREPARER);

                            ln_preparer_id   := NULL;

                            FETCH get_preparer_id_c INTO ln_preparer_id;

                            CLOSE get_preparer_id_c;

                            IF ln_preparer_id IS NULL
                            THEN
                                OPEN get_preparer_id_c ('Stewart, Celene');

                                FETCH get_preparer_id_c INTO ln_preparer_id;

                                CLOSE get_preparer_id_c; ---ADDED TO PUT STEWART AS DEFAULT PREPARER
                            END IF;
                        /* IF ln_preparer_id IS NULL
                         THEN
                            lc_recvalidation := 'N';
                            lc_h_err_msg :=
                               'Preparer does not exist in the system ';

                            --print_log_prc (p_debug, lc_h_err_msg);


                            XXD_common_utils.record_error (
                               'PORQV',
                               gn_org_id,
                               'Deckers PO Requisition Conversion',
                               'Preparer does not exist in the system ',
                               DBMS_UTILITY.format_error_backtrace,
                               gn_user_id,
                               gn_req_id,
                               gtt_req_val_int_tab (i).requisition_number,
                               gtt_req_val_int_tab (i).line_num,
                               'Preparer does not exist in the system ',
                               gtt_req_val_int_tab (i).DISTRIBUTION_ID);

                               ELSE
                               fnd_file.put_line (
                            fnd_file.LOG,'ln_preparer_id'||ln_preparer_id);
                         END IF;*/
                        ---COMMENTED ON 9TH MAY TO PUT STEWART AS DEFAULT PREPARER
                        ELSE
                            lc_recvalidation   := 'N';
                            lc_h_err_msg       :=
                                'Preparer should not be null ';

                            --print_log_prc (p_debug, lc_h_err_msg);


                            XXD_common_utils.record_error (
                                'PORQV',
                                gn_org_id,
                                'Deckers PO Requisition Conversion',
                                'Operating unit Mapping is not defined ',
                                DBMS_UTILITY.format_error_backtrace,
                                gn_user_id,
                                gn_req_id,
                                gtt_req_val_int_tab (i).requisition_number,
                                gtt_req_val_int_tab (i).line_num,
                                'Preparer should not be null ',
                                gtt_req_val_int_tab (i).DISTRIBUTION_ID);
                        END IF;

                        --End  Preparer validation


                        gc_code_pointer    := 'Validating  Requestor';

                        --Start requestor


                        IF gtt_req_val_int_tab (i).REQUESTOR IS NOT NULL
                        THEN
                            OPEN get_requestor_id_c (
                                gtt_req_val_int_tab (i).REQUESTOR);

                            ln_requestor_id   := NULL;

                            FETCH get_requestor_id_c INTO ln_requestor_id;

                            CLOSE get_requestor_id_c;

                            IF ln_requestor_id IS NULL
                            THEN
                                OPEN get_requestor_id_c ('Stewart, Celene');

                                FETCH get_requestor_id_c INTO ln_requestor_id;

                                CLOSE get_requestor_id_c; ---ADDED TO PUT STEWART AS DEFAULT REQUESTOR
                            END IF;
                        /* IF ln_requestor_id IS NULL
                         THEN
                            lc_recvalidation := 'N';
                            lc_h_err_msg :=
                                  lc_h_err_msg
                               || ' - Requestor does not exist in the system ';

                            --print_log_prc (p_debug, lc_h_err_msg);


                            XXD_common_utils.record_error (
                               'PORQV',
                               gn_org_id,
                               'Deckers PO Requisition Conversion',
                               'Operating unit Mapping is not defined ',
                               DBMS_UTILITY.format_error_backtrace,
                               gn_user_id,
                               gn_req_id,
                               gtt_req_val_int_tab (i).requisition_number,
                               gtt_req_val_int_tab (i).line_num,
                               'Requestor does not exist in the system ',
                               gtt_req_val_int_tab (i).DISTRIBUTION_ID);
                               ELSE
                               fnd_file.put_line (
                            fnd_file.LOG,'ln_requestor_id'||ln_requestor_id);
                         END IF;*/
                        ---COMMENTED ON 9TH MAY TO PUT STEWART AS DEFAULT REQUESTOR
                        ELSE
                            lc_recvalidation   := 'N';
                            lc_h_err_msg       :=
                                   lc_h_err_msg
                                || ' - Requestor does not exist in the system ';

                            --print_log_prc (p_debug, lc_h_err_msg);


                            XXD_common_utils.record_error (
                                'PORQV',
                                gn_org_id,
                                'Deckers PO Requisition Conversion',
                                'Operating unit Mapping is not defined ',
                                DBMS_UTILITY.format_error_backtrace,
                                gn_user_id,
                                gn_req_id,
                                gtt_req_val_int_tab (i).requisition_number,
                                gtt_req_val_int_tab (i).line_num,
                                'Requestor does not exist in the system ',
                                gtt_req_val_int_tab (i).DISTRIBUTION_ID);
                        END IF;

                        --End  Preparer validation

                        --End requestor

                        gc_code_pointer    := 'Validating  Agent';

                        fnd_file.put_line (
                            fnd_file.LOG,
                               'agent_name '
                            || gtt_req_val_int_tab (i).agent_name);


                        --Start Preparer validation
                        IF gtt_req_val_int_tab (i).agent_name IS NOT NULL
                        THEN
                            OPEN get_agent_id_c (
                                gtt_req_val_int_tab (i).agent_name);

                            ln_agent_id   := NULL;

                            FETCH get_agent_id_c INTO ln_agent_id;

                            CLOSE get_agent_id_c;

                            IF ln_agent_id IS NULL
                            THEN
                                OPEN get_agent_id_c ('Stewart, Celene');

                                FETCH get_agent_id_c INTO ln_agent_id;

                                CLOSE get_agent_id_c; ---ADDED TO PUT STEWART AS DEFAULT AGENT
                            END IF;

                            fnd_file.put_line (
                                fnd_file.LOG,
                                'ln_agent_id  ' || ln_agent_id);
                        /*   IF ln_agent_id IS NULL
                           THEN
                              lc_recvalidation := 'N';
                              lc_h_err_msg :=
                                 'Agent does not exist in the system ';

                              --print_log_prc (p_debug, lc_h_err_msg);


                              XXD_common_utils.record_error (
                                 'PORQV',
                                 gn_org_id,
                                 'Deckers PO Requisition Conversion',
                                 'agent does not exist in the system ',
                                 DBMS_UTILITY.format_error_backtrace,
                                 gn_user_id,
                                 gn_req_id,
                                 gtt_req_val_int_tab (i).requisition_number,
                                 gtt_req_val_int_tab (i).line_num,
                                 'agent does not exist in the system ',
                                 gtt_req_val_int_tab (i).DISTRIBUTION_ID);

                                 ELSE
                                 fnd_file.put_line (
                              fnd_file.LOG,'ln_agent_id'||ln_Agent_id);
                           END IF;*/
                        ---ADDED TO PUT STEWART AS DEFAULT AGENT
                        ELSE
                            lc_recvalidation   := 'N';
                            lc_h_err_msg       := 'agent should not be null ';

                            --print_log_prc (p_debug, lc_h_err_msg);


                            XXD_common_utils.record_error (
                                'PORQV',
                                gn_org_id,
                                'Deckers PO Requisition Conversion',
                                'Operating unit Mapping is not defined ',
                                DBMS_UTILITY.format_error_backtrace,
                                gn_user_id,
                                gn_req_id,
                                gtt_req_val_int_tab (i).requisition_number,
                                gtt_req_val_int_tab (i).line_num,
                                'agent should not be null ',
                                gtt_req_val_int_tab (i).DISTRIBUTION_ID);
                        END IF;

                        --End  Agent validation

                        --Category name Validation

                        /*      IF gtt_req_val_int_tab (i).CATEGORY_NAME IS NOT NULL
                              THEN
                                 OPEN get_preparer_id_c(gtt_req_val_int_tab (i).CATEGORY_NAME);

                                 ln_preparer_id := NULL;

                                 FETCH get_preparer_id_c INTO ln_preparer_id;

                                 CLOSE get_preparer_id_c;

                                 IF ln_preparer_id IS NULL
                                 THEN
                                    lc_recvalidation := 'N';
                                    lc_h_err_msg :=
                                          'Preparer does not exist in the system '
                                       || gtt_req_val_int_tab (i).REQUISTION_NUMBER;

                                    --print_log_prc (p_debug, lc_h_err_msg);


                                    XXD_common_utils.record_error (
                                       'POREQ',
                                       gn_org_id,
                                       'Deckers PO Requisition Conversion',
                                       lc_h_err_msg,
                                       DBMS_UTILITY.format_error_backtrace,
                                       gn_user_id,
                                       gn_req_id,
                                       'Code pointer : ' || gc_code_pointer,
                                       'XXD_PO_REQUISITION_CONV_STG_T');
                                 END IF;
                              ELSE
                                 lc_recvalidation := 'N';
                                 lc_h_err_msg :=
                                       'Preparer should not be null '
                                    || gtt_req_val_int_tab (i).REQUISTION_NUMBER;

                                 --print_log_prc (p_debug, lc_h_err_msg);


                                 XXD_common_utils.record_error (
                                    'POREQ',
                                    XXD_common_utils.get_org_id,
                                    'Deckers PO Requisition Conversion',
                                    lc_h_err_msg,
                                    DBMS_UTILITY.format_error_backtrace,
                                    gn_user_id,
                                    gn_req_id,
                                    'Code pointer : ' || gc_code_pointer,
                                    'XXD_PO_REQUISITION_CONV_STG_T');
                              END IF; */


                        /*                gc_code_pointer := 'Validating  Item_description ';

                                        --Start   Item description validation

                                        IF gtt_req_val_int_tab (i).Item_description IS NULL
                                        THEN
                                           lc_recvalidation := 'N';
                                           lc_h_err_msg := 'Item description should not be null ';

                                           --print_log_prc (p_debug, lc_h_err_msg);


                                           XXD_common_utils.record_error (
                                              'POREQVALIDATE',
                                              gn_org_id,
                                              'Deckers PO Requisition Conversion',
                                              lc_h_err_msg,
                                              DBMS_UTILITY.format_error_backtrace,
                                              gn_user_id,
                                              gn_req_id,
                                              'Code pointer : ' || gc_code_pointer,
                                              'XXD_PO_REQUISITION_CONV_STG_T');
                                        END IF;

                                        --End Item description validation */

                        gc_code_pointer    := 'Validating  UOM ';

                        /*           fnd_file.put_line (
                                      fnd_file.LOG,
                                         'gtt_req_val_int_tab (i).UNIT_MEAS_LOOKUP_CODE '
                                      || gtt_req_val_int_tab (i).UNIT_MEAS_LOOKUP_CODE); */

                        --Start  uom validation

                        IF gtt_req_val_int_tab (i).UNIT_MEAS_LOOKUP_CODE
                               IS NOT NULL
                        THEN
                            OPEN get_uom_c (
                                gtt_req_val_int_tab (i).UNIT_MEAS_LOOKUP_CODE);

                            lc_uom   := NULL;

                            FETCH get_uom_c INTO lc_uom;

                            --fnd_file.put_line (fnd_file.LOG, 'lc_uom ' || lc_uom);

                            CLOSE get_uom_c;

                            IF lc_uom IS NULL
                            THEN
                                lc_recvalidation   := 'N';
                                lc_h_err_msg       :=
                                       lc_h_err_msg
                                    || ' -  uom does not exist in the system ';

                                --print_log_prc (p_debug, lc_h_err_msg);


                                XXD_common_utils.record_error (
                                    'PORQV',
                                    gn_org_id,
                                    'Deckers PO Requisition Conversion',
                                    'Operating unit Mapping is not defined ',
                                    DBMS_UTILITY.format_error_backtrace,
                                    gn_user_id,
                                    gn_req_id,
                                    gtt_req_val_int_tab (i).requisition_number,
                                    gtt_req_val_int_tab (i).line_num,
                                    'uom does not exist in the system ',
                                    gtt_req_val_int_tab (i).DISTRIBUTION_ID);
                            END IF;
                        ELSE
                            lc_recvalidation   := 'N';
                            lc_h_err_msg       :=
                                lc_h_err_msg || ' -  uom should not be null ';

                            --print_log_prc (p_debug, lc_h_err_msg);



                            XXD_common_utils.record_error (
                                'PORQV',
                                gn_org_id,
                                'Deckers PO Requisition Conversion',
                                'Operating unit Mapping is not defined ',
                                DBMS_UTILITY.format_error_backtrace,
                                gn_user_id,
                                gn_req_id,
                                gtt_req_val_int_tab (i).requisition_number,
                                gtt_req_val_int_tab (i).line_num,
                                'uom should not be null ',
                                gtt_req_val_int_tab (i).DISTRIBUTION_ID);
                        END IF;

                        --End  uom validation



                        gc_code_pointer    :=
                            'Validating  Inventory Organization ';


                        --Inventory Dest Organization id
                        IF gtt_req_val_int_tab (i).destination_organization_name
                               IS NOT NULL
                        THEN
                            --Inventory org id

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'gtt_req_val_int_tab (i).destination_organization_name '
                                || gtt_req_val_int_tab (i).destination_organization_name);

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'requisition_number '
                                || gtt_req_val_int_tab (i).requisition_number);

                            XXD_COMMON_UTILS.GET_MAPPING_VALUE (
                                p_lookup_type    => 'XXD_1206_INV_ORG_MAPPING',
                                px_lookup_code   =>
                                    gtt_req_val_int_tab (i).DESTINATION_ORGANIZATION_ID,
                                px_meaning       => xc_meaning,
                                px_description   => xc_description,
                                x_attribute1     =>
                                    lc_new_dest_organization_code,
                                x_attribute2     => lc_attribute2,
                                x_error_code     => lc_error_code,
                                x_error_msg      => lc_error_msg);


                            --End Inventory org id

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'lc_new_dest_organization_code '
                                || lc_new_dest_organization_code);

                            --Added for 3PL Requirement on --06-NOV-2015
                            l_po_num                  := NULL;

                            BEGIN
                                SELECT DISTINCT lookup_code
                                  INTO l_po_num
                                  FROM apps.fnd_lookup_values
                                 WHERE     lookup_type = 'XXDO_EU8_PO_CONV'
                                       AND lookup_code =
                                           TO_CHAR (
                                               gtt_req_val_int_tab (i).PO_NUMBER);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_po_num   := NULL;
                            END;


                            IF l_po_num IS NOT NULL
                            THEN
                                lc_new_dest_organization_code   := 'EU8';
                            END IF;

                            OPEN get_organization_id_c (
                                lc_new_dest_organization_code);

                            ln_dest_organization_ID   := NULL;

                            FETCH get_organization_id_c
                                INTO ln_dest_organization_ID;

                            CLOSE get_organization_id_c;

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'ln_dest_organization_ID '
                                || ln_dest_organization_ID);


                            IF ln_dest_organization_ID IS NULL
                            THEN
                                lc_recvalidation   := 'N';
                                lc_h_err_msg       :=
                                       lc_h_err_msg
                                    || ' -  Could not derive the destination inventory org ';

                                --print_log_prc (p_debug, lc_h_err_msg);


                                XXD_common_utils.record_error (
                                    'PORQV',
                                    gn_org_id,
                                    'Deckers PO Requisition Conversion',
                                    'Operating unit Mapping is not defined ',
                                    DBMS_UTILITY.format_error_backtrace,
                                    gn_user_id,
                                    gn_req_id,
                                    gtt_req_val_int_tab (i).requisition_number,
                                    gtt_req_val_int_tab (i).line_num,
                                    'Could not derive the destination inventory org ',
                                    gtt_req_val_int_tab (i).DISTRIBUTION_ID);
                            ELSE
                                OPEN get_org_id_c (ln_dest_organization_ID,
                                                   ln_org_id);

                                ln_org_id1   := NULL;

                                FETCH get_org_id_c INTO ln_org_id1;

                                CLOSE get_org_id_c;

                                --fnd_file.put_line (fnd_file.LOG,                                           'ln_org_id1 ' || ln_org_id1);

                                IF ln_org_id1 IS NULL
                                THEN
                                    lc_recvalidation   := 'N';
                                    lc_h_err_msg       :=
                                           lc_h_err_msg
                                        || ' -  Destination org does not belong to Requisition OU ';

                                    --print_log_prc (p_debug, lc_h_err_msg);


                                    XXD_common_utils.record_error (
                                        'PORQV',
                                        gn_org_id,
                                        'Deckers PO Requisition Conversion',
                                        'Operating unit Mapping is not defined ',
                                        DBMS_UTILITY.format_error_backtrace,
                                        gn_user_id,
                                        gn_req_id,
                                        gtt_req_val_int_tab (i).requisition_number,
                                        gtt_req_val_int_tab (i).line_num,
                                        'Destination org does not belong to Requisition OU ',
                                        gtt_req_val_int_tab (i).DISTRIBUTION_ID);
                                END IF;
                            END IF;
                        ELSE
                            lc_recvalidation   := 'N';
                            lc_h_err_msg       :=
                                   lc_h_err_msg
                                || ' -  Inventory org name can not be null ';

                            --print_log_prc (p_debug, lc_h_err_msg);


                            XXD_common_utils.record_error (
                                'PORQV',
                                gn_org_id,
                                'Deckers PO Requisition Conversion',
                                'Operating unit Mapping is not defined ',
                                DBMS_UTILITY.format_error_backtrace,
                                gn_user_id,
                                gn_req_id,
                                gtt_req_val_int_tab (i).requisition_number,
                                gtt_req_val_int_tab (i).line_num,
                                'Inventory org name can not be null  ',
                                gtt_req_val_int_tab (i).DISTRIBUTION_ID);
                        END IF;


                        --End --Inventory Dest Organization id



                        gc_code_pointer    := 'Validating  location_code ';



                        --Location code

                        IF gtt_req_val_int_tab (i).location_code IS NOT NULL
                        THEN
                            OPEN get_location_id_c ( --gtt_req_val_int_tab (i).location_code
                                                    ln_dest_organization_ID);

                            ln_location_id   := NULL;

                            FETCH get_location_id_c INTO ln_location_id;

                            CLOSE get_location_id_c;

                            IF ln_location_id IS NULL
                            THEN
                                lc_recvalidation   := 'N';
                                lc_h_err_msg       :=
                                       lc_h_err_msg
                                    || ' -  Location code does not exist in the system or not associated with dest org';

                                --print_log_prc (p_debug, lc_h_err_msg);


                                XXD_common_utils.record_error (
                                    'PORQV',
                                    gn_org_id,
                                    'Deckers PO Requisition Conversion',
                                    'Operating unit Mapping is not defined ',
                                    DBMS_UTILITY.format_error_backtrace,
                                    gn_user_id,
                                    gn_req_id,
                                    gtt_req_val_int_tab (i).requisition_number,
                                    gtt_req_val_int_tab (i).line_num,
                                    'Location code does not exist in the system or not associated with dest org  ',
                                    gtt_req_val_int_tab (i).DISTRIBUTION_ID);
                            /*ELSE
                              OPEN Get_loc_id_c (ln_location_id);

                               ln_loc_id := NULL;

                               FETCH Get_loc_id_c INTO ln_loc_id;

                               CLOSE Get_loc_id_c;

                               IF ln_loc_id IS NULL
                               THEN
                                  lc_recvalidation := 'N';
                                  lc_h_err_msg :=
                                        lc_h_err_msg
                                     || ' -  Check customer association for loc';

                                  --print_log_prc (p_debug, lc_h_err_msg);


                                  XXD_common_utils.record_error (
                                     'PORQV',
                                     gn_org_id,
                                     'Deckers PO Requisition Conversion',
                                     'Operating unit Mapping is not defined ',
                                     DBMS_UTILITY.format_error_backtrace,
                                     gn_user_id,
                                     gn_req_id,
                                     gtt_req_val_int_tab (i).requisition_number,
                                     gtt_req_val_int_tab (i).line_num,
                                     'Check customer association for loc  ',
                                     gtt_req_val_int_tab (i).DISTRIBUTION_ID);
                               END IF; */
                            END IF;
                        ELSE
                            lc_recvalidation   := 'N';
                            lc_h_err_msg       :=
                                   lc_h_err_msg
                                || ' -  Location code should not be null ';

                            --print_log_prc (p_debug, lc_h_err_msg);


                            XXD_common_utils.record_error (
                                'PORQV',
                                gn_org_id,
                                'Deckers PO Requisition Conversion',
                                'Location code should not be null ',
                                DBMS_UTILITY.format_error_backtrace,
                                gn_user_id,
                                gn_req_id,
                                gtt_req_val_int_tab (i).requisition_number,
                                gtt_req_val_int_tab (i).line_num,
                                'Location code should not be null  ',
                                gtt_req_val_int_tab (i).DISTRIBUTION_ID);
                        END IF;


                        --End of location code

                        /* IF gtt_req_val_int_tab (i).SCENARIO = 'EUROPE'
                         THEN
                            ln_source_organization_ID :=
                               gtt_req_val_int_tab (i).source_organization_ID;

                            fnd_file.put_line (
                               fnd_file.LOG,
                                  'ln_source_organization_ID  '
                               || ln_source_organization_ID);
                         ELSE*/
                        ---COMMENTED 070815
                        --Inventory source Organization id
                        IF gtt_req_val_int_tab (i).Source_organization_name
                               IS NOT NULL
                        THEN
                            --Inventory org id


                            XXD_COMMON_UTILS.GET_MAPPING_VALUE (
                                p_lookup_type    => 'XXD_1206_INV_ORG_MAPPING',
                                px_lookup_code   =>
                                    gtt_req_val_int_tab (i).source_ORGANIZATION_ID,
                                px_meaning       => xc_meaning,
                                px_description   => xc_description,
                                x_attribute1     => lc_new_source_org_code,
                                x_attribute2     => lc_attribute2,
                                x_error_code     => lc_error_code,
                                x_error_msg      => lc_error_msg);


                            --End Inventory org id

                            OPEN get_organization_id_c (
                                lc_new_source_org_code);

                            ln_source_organization_ID   := NULL;

                            FETCH get_organization_id_c
                                INTO ln_source_organization_ID;

                            CLOSE get_organization_id_c;

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'ln_source_organization_ID  '
                                || ln_source_organization_ID);

                            IF ln_source_organization_ID IS NULL
                            THEN
                                lc_recvalidation   := 'N';
                                lc_h_err_msg       :=
                                       lc_h_err_msg
                                    || ' -  Could not derive the source inventory org ';

                                --print_log_prc (p_debug, lc_h_err_msg);


                                XXD_common_utils.record_error (
                                    'PORQV',
                                    gn_org_id,
                                    'Deckers PO Requisition Conversion',
                                    'Operating unit Mapping is not defined ',
                                    DBMS_UTILITY.format_error_backtrace,
                                    gn_user_id,
                                    gn_req_id,
                                    gtt_req_val_int_tab (i).requisition_number,
                                    gtt_req_val_int_tab (i).line_num,
                                    'Could not derive the source inventory org ',
                                    gtt_req_val_int_tab (i).DISTRIBUTION_ID);
                            END IF;
                        /*   ELSE
                              lc_recvalidation := 'N';
                              lc_h_err_msg :=
                                    lc_h_err_msg
                                 || ' -  Source Inventory org name can not be null ';

                              --print_log_prc (p_debug, lc_h_err_msg);


                              XXD_common_utils.record_error (
                                 'PORQV',
                                 gn_org_id,
                                 'Deckers PO Requisition Conversion',
                                 lc_h_err_msg,
                                 DBMS_UTILITY.format_error_backtrace,
                                 gn_user_id,
                                 gn_req_id,
                                 'Code pointer : ' || gc_code_pointer,
                                 'XXD_PO_REQUISITION_CONV_STG_T'); */
                        END IF;

                        -- END IF;


                        --End --Inventory Organization id


                        gc_code_pointer    := 'Validating  Item Number';


                        --Item Validation

                        --fnd_file.put_line (                      fnd_file.LOG,                     'Item ' || gtt_req_val_int_tab (i).ITEM_NUMBER);

                        IF gtt_req_val_int_tab (i).ITEM_NUMBER IS NOT NULL
                        THEN
                            OPEN get_val_item_c (
                                gtt_req_val_int_tab (i).ITEM_NUMBER);

                            /* fnd_file.put_line (
                                fnd_file.LOG,
                                'ln_organization_ID ' || ln_organization_ID);
                             fnd_file.put_line (
                                fnd_file.LOG,
                                'ITEM NUMBER ' || gtt_req_val_int_tab (i).ITEM_NUMBER); */

                            ln_inventory_item_id   := NULL;
                            lc_description         := NULL;

                            FETCH get_val_item_c INTO ln_inventory_item_id, lc_description;

                            CLOSE get_val_item_c;

                            IF ln_inventory_item_id IS NULL
                            THEN
                                lc_recvalidation   := 'N';
                                lc_h_err_msg       :=
                                       lc_h_err_msg
                                    || ' -  Item does not exist in the system ';

                                --print_log_prc (p_debug, lc_h_err_msg);


                                XXD_common_utils.record_error (
                                    'PORQV',
                                    gn_org_id,
                                    'Deckers PO Requisition Conversion',
                                    'Operating unit Mapping is not defined ',
                                    DBMS_UTILITY.format_error_backtrace,
                                    gn_user_id,
                                    gn_req_id,
                                    gtt_req_val_int_tab (i).requisition_number,
                                    gtt_req_val_int_tab (i).line_num,
                                    'Item does not exist in the system ',
                                    gtt_req_val_int_tab (i).DISTRIBUTION_ID);
                            ELSE
                                IF ln_dest_organization_ID =
                                   ln_source_organization_ID
                                THEN
                                    lc_recvalidation   := 'N';
                                    lc_h_err_msg       :=
                                           lc_h_err_msg
                                        || ' -   source or destination org are same ';

                                    --print_log_prc (p_debug, lc_h_err_msg);


                                    XXD_common_utils.record_error (
                                        'PORQV',
                                        gn_org_id,
                                        'Deckers PO Requisition Conversion',
                                        'Operating unit Mapping is not defined ',
                                        DBMS_UTILITY.format_error_backtrace,
                                        gn_user_id,
                                        gn_req_id,
                                        gtt_req_val_int_tab (i).requisition_number,
                                        gtt_req_val_int_tab (i).line_num,
                                        'source or destination org are same  ',
                                        gtt_req_val_int_tab (i).DISTRIBUTION_ID);
                                ELSE
                                    OPEN get_val_item_cnt_c (
                                        ln_inventory_item_id,
                                        ln_dest_organization_ID,
                                        ln_source_organization_ID);

                                    ln_count   := NULL;

                                    FETCH get_val_item_cnt_c INTO ln_count;

                                    CLOSE get_val_item_cnt_c;

                                    IF ln_count < 2
                                    THEN
                                        lc_recvalidation   := 'N';
                                        lc_h_err_msg       :=
                                               lc_h_err_msg
                                            || ' -  Item does not exist in the source or destination org ';

                                        --print_log_prc (p_debug, lc_h_err_msg);


                                        XXD_common_utils.record_error (
                                            'PORQV',
                                            gn_org_id,
                                            'Deckers PO Requisition Conversion',
                                            'Operating unit Mapping is not defined ',
                                            DBMS_UTILITY.format_error_backtrace,
                                            gn_user_id,
                                            gn_req_id,
                                            gtt_req_val_int_tab (i).requisition_number,
                                            gtt_req_val_int_tab (i).line_num,
                                            'Item does not exist in the source or destination org ',
                                            gtt_req_val_int_tab (i).DISTRIBUTION_ID);
                                    END IF;
                                END IF;
                            END IF;
                        ELSE
                            lc_recvalidation   := 'N';
                            lc_h_err_msg       :=
                                   lc_h_err_msg
                                || ' -  Item should not be null ';

                            --print_log_prc (p_debug, lc_h_err_msg);


                            XXD_common_utils.record_error (
                                'PORQV',
                                gn_org_id,
                                'Deckers PO Requisition Conversion',
                                'Operating unit Mapping is not defined ',
                                DBMS_UTILITY.format_error_backtrace,
                                gn_user_id,
                                gn_req_id,
                                gtt_req_val_int_tab (i).requisition_number,
                                gtt_req_val_int_tab (i).line_num,
                                'Item should not be null ',
                                gtt_req_val_int_tab (i).DISTRIBUTION_ID);
                        END IF;

                        --End Item


                        gc_code_pointer    := 'Validating  Line type';

                        --Start line type


                        IF gtt_req_val_int_tab (i).line_type IS NOT NULL
                        THEN
                            OPEN get_line_type_id_c (
                                gtt_req_val_int_tab (i).LINE_TYPE);

                            ln_line_type_id   := NULL;

                            FETCH get_line_type_id_c INTO ln_line_type_id;

                            CLOSE get_line_type_id_c;

                            IF ln_line_type_id IS NULL
                            THEN
                                lc_recvalidation   := 'N';
                                lc_h_err_msg       :=
                                       lc_h_err_msg
                                    || ' -  Line type does not exist in the system ';

                                --print_log_prc (p_debug, lc_h_err_msg);


                                XXD_common_utils.record_error (
                                    'PORQV',
                                    gn_org_id,
                                    'Deckers PO Requisition Conversion',
                                    'Operating unit Mapping is not defined ',
                                    DBMS_UTILITY.format_error_backtrace,
                                    gn_user_id,
                                    gn_req_id,
                                    gtt_req_val_int_tab (i).requisition_number,
                                    gtt_req_val_int_tab (i).line_num,
                                    'Line type does not exist in the system ',
                                    gtt_req_val_int_tab (i).DISTRIBUTION_ID);
                            END IF;
                        ELSE
                            lc_recvalidation   := 'N';
                            lc_h_err_msg       :=
                                   lc_h_err_msg
                                || ' -  Line type  should not be null ';

                            --print_log_prc (p_debug, lc_h_err_msg);


                            XXD_common_utils.record_error (
                                'PORQV',
                                gn_org_id,
                                'Deckers PO Requisition Conversion',
                                'Operating unit Mapping is not defined ',
                                DBMS_UTILITY.format_error_backtrace,
                                gn_user_id,
                                gn_req_id,
                                gtt_req_val_int_tab (i).requisition_number,
                                gtt_req_val_int_tab (i).line_num,
                                ' Line type  should not be null ',
                                gtt_req_val_int_tab (i).DISTRIBUTION_ID);
                        END IF;


                        --End line type


                        gc_code_pointer    := 'Deriving New code combination';

                        --Gl_code_combination

                        IF     gtt_req_val_int_tab (i).segment1 IS NOT NULL
                           AND gtt_req_val_int_tab (i).segment2 IS NOT NULL
                           AND gtt_req_val_int_tab (i).segment3 IS NOT NULL
                           AND gtt_req_val_int_tab (i).segment4 IS NOT NULL
                        THEN
                            lc_new_conc_segs   :=
                                XXD_COMMON_UTILS.get_gl_code_combination (
                                    gtt_req_val_int_tab (i).segment1,
                                    gtt_req_val_int_tab (i).segment2,
                                    gtt_req_val_int_tab (i).segment3,
                                    gtt_req_val_int_tab (i).segment4);



                            OPEN get_code_comb_id_c (lc_new_conc_segs);

                            ln_ccid   := NULL;

                            FETCH get_code_comb_id_c INTO ln_ccid;

                            CLOSE get_code_comb_id_c;

                            IF ln_ccid IS NOT NULL
                            THEN
                                ------------------------The CCID is Available----------------------
                                gc_code_pointer   :=
                                    'Code Combination Id Exists';
                            --print_log_prc (p_debug, gc_code_pointer);

                            ELSE
                                gc_code_pointer   := 'Deriving coa id ';

                                OPEN get_coa_id_c (ln_org_id);

                                FETCH get_coa_id_c INTO ln_coa_id;

                                CLOSE get_coa_id_c;


                                gc_code_pointer   :=
                                    'Calling Fnd_Flex_Ext.get_ccid ';


                                BEGIN
                                    ln_ccid   :=
                                        Fnd_Flex_Ext.get_ccid (
                                            'SQLGL',
                                            'GL#',
                                            ln_coa_id,
                                            NULL,
                                            lc_new_conc_segs);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        ln_ccid            := NULL;
                                        lc_h_err_msg       :=
                                               lc_h_err_msg
                                            || ' -  Fnd_Flex_Ext.get_ccid failed to derive ccid';
                                        lc_recvalidation   := 'N';
                                END;
                            END IF;



                            IF ln_ccid IS NOT NULL
                            THEN
                                gc_code_pointer   :=
                                    'Fetching the New CCID from gl_code_combinations ';

                                OPEN get_code_comb_id_c (lc_new_conc_segs);

                                FETCH get_code_comb_id_c INTO ln_ccid;

                                CLOSE get_code_comb_id_c;
                            ELSE
                                lc_h_err_msg       :=
                                       lc_h_err_msg
                                    || ' -  Fnd_Flex_Ext.get_ccid failed to derive ccid';

                                lc_recvalidation   := 'N';
                            END IF;
                        ELSE
                            ln_ccid            := NULL;
                            lc_h_err_msg       :=
                                   lc_h_err_msg
                                || ' -  Segment values for the line are null in 12.0.6';
                            lc_recvalidation   := 'N';
                        END IF;

                        --End gl_code_cobination


                        gc_code_pointer    := 'Updating Staging table  ';
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'lc_recvalidation' || lc_recvalidation);


                        IF lc_recvalidation = 'N'
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'ln_dest_organization_ID in  '
                                || ln_dest_organization_ID);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'DISTRIBUTION_ID in  '
                                || gtt_req_val_int_tab (i).DISTRIBUTION_ID);

                            UPDATE XXD_PO_REQUISITION_CONV_STG_T
                               SET record_status = 'E', error_message1 = lc_h_err_msg, request_id = fnd_global.conc_request_id,
                                   NEW_ORG_ID = ln_org_id, NEW_CHARGE_ACCOUNT_ID = ln_ccid, --NEW_CATEGORY_ID   =
                                                                                            NEW_LINE_TYPE_ID = ln_line_type_id,
                                   NEW_DEST_ORGANIZATION_ID = ln_dest_organization_ID, NEW_SOURCE_ORGANIZATION_ID = ln_source_organization_ID, NEW_DELIVER_TO_LOCATION_ID = ln_location_id,
                                   NEW_REQUESTOR_ID = ln_requestor_id, NEW_INVENTORY_ITEM_ID = ln_inventory_item_id, NEW_PREPARER_ID = ln_preparer_id,
                                   new_agent_id = ln_agent_id, ITEM_DESCRIPTION = lc_description
                             WHERE     DISTRIBUTION_ID =
                                       gtt_req_val_int_tab (i).DISTRIBUTION_ID
                                   AND SCENARIO = NVL (p_scenario, SCENARIO);

                            SELECT NEW_DEST_ORGANIZATION_ID
                              INTO ln_DISTRIBUTION_ID
                              FROM XXD_PO_REQUISITION_CONV_STG_T
                             WHERE DISTRIBUTION_ID = 1893421;

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'ln_DISTRIBUTION_ID in 1  '
                                || ln_DISTRIBUTION_ID);


                            UPDATE XXD_PO_REQUISITION_CONV_STG_T
                               SET record_status = 'E', error_message2 = 'One of the lines failed'
                             /*  request_id = fnd_global.conc_request_id,
                               NEW_ORG_ID = ln_org_id,
                               NEW_CHARGE_ACCOUNT_ID = ln_ccid,
                               --NEW_CATEGORY_ID   =
                               NEW_LINE_TYPE_ID = ln_line_type_id,
                               NEW_DEST_ORGANIZATION_ID = ln_dest_organization_ID,
                               NEW_SOURCE_ORGANIZATION_ID =
                                  ln_source_organization_ID,
                               NEW_DELIVER_TO_LOCATION_ID = ln_location_id,
                               NEW_REQUESTOR_ID = ln_requestor_id,
                               NEW_INVENTORY_ITEM_ID = ln_inventory_item_id,
                               NEW_PREPARER_ID = ln_preparer_id,
                               ITEM_DESCRIPTION = lc_description */
                             WHERE     old_requisition_header_id =
                                       gtt_req_val_int_tab (i).old_requisition_header_id
                                   AND SCENARIO = NVL (p_scenario, SCENARIO);

                            SELECT NEW_DEST_ORGANIZATION_ID
                              INTO ln_DISTRIBUTION_ID
                              FROM XXD_PO_REQUISITION_CONV_STG_T
                             WHERE DISTRIBUTION_ID = 1893421;

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'ln_DISTRIBUTION_ID in 2 '
                                || ln_DISTRIBUTION_ID);
                        ELSE
                            fnd_file.put_line (fnd_file.LOG, 'INSIDE ELSE');

                            UPDATE XXD_PO_REQUISITION_CONV_STG_T
                               SET record_status = 'V', NEW_ORG_ID = ln_org_id, request_id = fnd_global.conc_request_id,
                                   NEW_CHARGE_ACCOUNT_ID = ln_ccid, --NEW_CATEGORY_ID   =
                                                                    NEW_LINE_TYPE_ID = ln_line_type_id, NEW_DEST_ORGANIZATION_ID = ln_dest_organization_ID,
                                   NEW_SOURCE_ORGANIZATION_ID = ln_source_organization_ID, NEW_DELIVER_TO_LOCATION_ID = ln_location_id, NEW_REQUESTOR_ID = ln_requestor_id,
                                   NEW_INVENTORY_ITEM_ID = ln_inventory_item_id, NEW_PREPARER_ID = ln_preparer_id, new_agent_id = ln_agent_id,
                                   ITEM_DESCRIPTION = lc_description, vendor_id = ln_vendor_id, vendor_site_id = ln_vendor_site_id,
                                   error_message1 = NULL, error_message2 = NULL
                             WHERE     DISTRIBUTION_ID =
                                       gtt_req_val_int_tab (i).DISTRIBUTION_ID
                                   AND record_status IN ('N', 'E')
                                   AND SCENARIO = NVL (p_scenario, SCENARIO);

                            /*SELECT NEW_DEST_ORGANIZATION_ID
                              INTO ln_DISTRIBUTION_ID
                              FROM XXD_PO_REQUISITION_CONV_STG_T
                             WHERE DISTRIBUTION_ID = 1893421;*/

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'ln_DISTRIBUTION_ID in 3 '
                                || ln_DISTRIBUTION_ID);
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lc_h_err_msg         := SQLERRM;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error '
                                || lc_h_err_msg
                                || ' for dist id '
                                || gtt_req_val_int_tab (i).DISTRIBUTION_ID);
                            XXD_common_utils.record_error (
                                'PORQV',
                                gn_org_id,
                                'Deckers PO Requisition Conversion',
                                lc_h_err_msg,
                                DBMS_UTILITY.format_error_backtrace,
                                gn_user_id,
                                gn_req_id,
                                'Code pointer : ' || gc_code_pointer,
                                'XXD_PO_REQUISITION_CONV_STG_T');

                            gn_DISTRIBUTION_ID   :=
                                gtt_req_val_int_tab (i).DISTRIBUTION_ID;
                            x_retcode            := 1;
                    END;
                END LOOP;

                COMMIT;
            ELSE
                EXIT;
            END IF;
        END LOOP;

        CLOSE requisition_val_c;

        COMMIT;

        -- NULL;


        SELECT COUNT (*)
          INTO gn_inv_validate
          FROM XXD_PO_REQUISITION_CONV_STG_T
         WHERE     record_status = 'V'
               AND WORKER_BATCH_NUMBER = p_batch_no
               AND SCENARIO = NVL (p_scenario, SCENARIO);


        SELECT COUNT (*)
          INTO gn_inv_error
          FROM XXD_PO_REQUISITION_CONV_STG_T
         WHERE     record_status = 'E'
               AND WORKER_BATCH_NUMBER = p_batch_no
               AND SCENARIO = NVL (p_scenario, SCENARIO);

        IF NVL (gn_inv_validate, 0) > 0
        THEN
            x_retcode   := 1;
        ELSIF NVL (gn_inv_validate, 0) = 0
        THEN
            x_retcode   := 2;
        END IF;

        -- Writing Counts to output file.

        fnd_file.put_line (fnd_file.OUTPUT,
                           'Deckers PO Requisition Conversion  ');
        fnd_file.put_line (
            fnd_file.OUTPUT,
            '-------------------------------------------------');

        fnd_file.put_line (
            fnd_file.OUTPUT,
               'Total no records validated in XXD_PO_REQUISITION_CONV_STG_T Table '
            || gn_inv_validate);
        fnd_file.put_line (
            fnd_file.OUTPUT,
               'Total no records errored in XXD_PO_REQUISITION_CONV_STG_T Table '
            || gn_inv_error);
        fnd_file.put_line (
            fnd_file.OUTPUT,
            '                                                 ');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'OTHERS Exception in VALIDATE_REQUISITION_PROC procedure '
                || SQLERRM);

            x_retcode   := 2;

            XXD_common_utils.record_error (
                'PORQV',
                gn_org_id,
                'Deckers PO Requisition Conversion',
                   'Error for dist id '
                || gn_DISTRIBUTION_ID
                || ' is '
                || SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                gn_user_id,
                gn_req_id,
                'Code pointer : ' || gc_code_pointer,
                'XXD_PO_REQUISITION_CONV_STG_T');
    END VALIDATE_REQUISITION_PROC;

    --Interface

    /****************************************************************************************
       * Procedure : INTERFACE_REQUISITION_PROC
       * Synopsis  : This Procedure is called by val_load_main_prc Main procedure
       * Design    : Procedure loads data to staging table for AP Invoice Conversion
       * Notes     :
       * Return Values: None
       * Modification :
       * Date          Developer             Version    Description
       *--------------------------------------------------------------------------------------
       * 07-JUL-2014   BT Technoloy team       1.00       Created
       ****************************************************************************************/


    PROCEDURE INTERFACE_REQUISITION_PROC (x_retcode       OUT NUMBER,
                                          x_errbuff       OUT VARCHAR2,
                                          p_batch_no   IN     NUMBER,
                                          p_debug      IN     VARCHAR2,
                                          p_scenario   IN     VARCHAR2)
    IS
        CURSOR requisition_int_c IS
            SELECT /*+ FIRST_ROWS(100) */
                   AUTHORIZATION_STATUS, CATEGORY_ID, DISTRIBUTION_ID,
                   CATEGORY_NAME, CHARGE_ACCOUNT_ID, CONCATENATED_SEGMENTS,
                   DELIVER_TO_LOCATION_ID, DESTINATION_ORGANIZATION_ID, OLD_REQUISITION_HEADER_ID,
                   REQUISITION_line_ID, NEW_ORG_ID, NEW_CHARGE_ACCOUNT_ID,
                   NEW_CATEGORY_ID, NEW_LINE_TYPE_ID, NEW_DEST_ORGANIZATION_ID,
                   NEW_DELIVER_TO_LOCATION_ID, NEW_REQUESTOR_ID, NEW_INVENTORY_ITEM_ID,
                   NEW_PREPARER_ID, DESTINATION_TYPE_CODE, INTERFACE_SOURCE_CODE,
                   ITEM_NUMBER, ITEM_DESCRIPTION, ITEM_ID,
                   LINE_TYPE, LINE_TYPE_ID, LOCATION_CODE,
                   NEED_BY_DATE, OPERATING_UNIT, destination_organization_name,
                   DESTINATION_SUBINVENTORY, new_source_organization_id, ORG_ID,
                   PREPARER, PREPARER_ID, QUANTITY,
                   REQUESTOR, REQUISITION_TYPE, REQUISiTION_NUMBER,
                   SEGMENT1, SEGMENT2, SEGMENT3,
                   SEGMENT4, SOURCE_TYPE_CODE, TO_PERSON_ID,
                   UNIT_MEAS_LOOKUP_CODE, UNIT_PRICE, REQ_HEADER_ATTRIBUTE_CATEGORY,
                   REQ_HEADER_ATTRIBUTE1, REQ_HEADER_ATTRIBUTE2, REQ_HEADER_ATTRIBUTE3,
                   REQ_HEADER_ATTRIBUTE4, REQ_HEADER_ATTRIBUTE5, REQ_HEADER_ATTRIBUTE6,
                   REQ_HEADER_ATTRIBUTE7, REQ_HEADER_ATTRIBUTE8, REQ_HEADER_ATTRIBUTE9,
                   REQ_HEADER_ATTRIBUTE10, REQ_HEADER_ATTRIBUTE11, REQ_HEADER_ATTRIBUTE12,
                   REQ_HEADER_ATTRIBUTE13, REQ_HEADER_ATTRIBUTE14, REQ_HEADER_ATTRIBUTE15,
                   REQ_LINE_ATTRIBUTE_CATEGORY, REQ_LINE_ATTRIBUTE1, REQ_LINE_ATTRIBUTE2,
                   REQ_LINE_ATTRIBUTE3, REQ_LINE_ATTRIBUTE4, REQ_LINE_ATTRIBUTE5,
                   REQ_LINE_ATTRIBUTE6, REQ_LINE_ATTRIBUTE7, REQ_LINE_ATTRIBUTE8,
                   REQ_LINE_ATTRIBUTE9, REQ_LINE_ATTRIBUTE10, REQ_LINE_ATTRIBUTE11,
                   REQ_LINE_ATTRIBUTE12, REQ_LINE_ATTRIBUTE13, REQ_LINE_ATTRIBUTE14,
                   REQ_LINE_ATTRIBUTE15, REQ_DIST_ATTRIBUTE_CATEGORY, REQ_DIST_ATTRIBUTE1,
                   REQ_DIST_ATTRIBUTE2, REQ_DIST_ATTRIBUTE3, REQ_DIST_ATTRIBUTE4,
                   REQ_DIST_ATTRIBUTE5, REQ_DIST_ATTRIBUTE6, REQ_DIST_ATTRIBUTE7,
                   REQ_DIST_ATTRIBUTE8, REQ_DIST_ATTRIBUTE9, REQ_DIST_ATTRIBUTE10,
                   REQ_DIST_ATTRIBUTE11, REQ_DIST_ATTRIBUTE12, REQ_DIST_ATTRIBUTE13,
                   REQ_DIST_ATTRIBUTE14, REQ_DIST_ATTRIBUTE15, LINE_NUM,
                   SHIPMENT_NUM,                            --ADDED ON 19THMAY
                                 worker_batch_number, PO_LINE_ID,
                   IR_creation_date
              FROM XXD_PO_REQUISITION_CONV_STG_T
             WHERE     1 = 1
                   AND record_status = 'V'
                   AND new_org_id = p_batch_no --  AND worker_batch_number = p_batch_no    --Added on 10-MAY-2015
                   AND SCENARIO = NVL (p_scenario, SCENARIO); --AND OLD_REQUISITION_HEADER_ID = 20054

        --AND REQUISTION_NUMBER = '10'



        TYPE xxd_requisition_int_tab IS TABLE OF requisition_int_c%ROWTYPE
            INDEX BY BINARY_INTEGER;

        gtt_req_interface_tab   xxd_requisition_int_tab;

        ln_loop_counter         NUMBER;
        gn_inv_int              NUMBER;
        ln_count                NUMBER;
        p_batch_id              NUMBER;
    BEGIN
        --fnd_file.put_line (fnd_file.LOG, 'Test100');

        gc_code_pointer   := 'Insert into   Interface table';

        --fnd_file.put_line (fnd_file.LOG, 'Test101');

        -- Insert records into Invoice  staging table

        SELECT apps.XXD_ONT_DS_SO_REQ_BATCH_S.NEXTVAL
          INTO p_batch_id
          FROM DUAL;                                       ---added on 28thmay

        OPEN requisition_int_c;

        ln_loop_counter   := 0;

        --DELETE po_requisitions_interface_all;

        COMMIT;

        --fnd_file.put_line (fnd_file.LOG, 'Test1');

        LOOP
            --fnd_file.put_line (fnd_file.LOG, 'Test2');

            FETCH requisition_int_c
                BULK COLLECT INTO gtt_req_interface_tab
                LIMIT gn_limit;

            fnd_file.put_line (fnd_file.LOG, 'p_batch_no ' || p_batch_no);
            fnd_file.put_line (fnd_file.LOG,
                               'Count ' || gtt_req_interface_tab.COUNT);

            IF gtt_req_interface_tab.COUNT > 0
            THEN
                BEGIN
                    FORALL i IN 1 .. gtt_req_interface_tab.COUNT
                      SAVE EXCEPTIONS
                        INSERT INTO po_requisitions_interface_all (
                                        interface_source_code,
                                        org_id,
                                        destination_type_code,
                                        authorization_status,
                                        preparer_id,
                                        charge_account_id,
                                        source_type_code,
                                        unit_of_measure,
                                        line_type_id,
                                        --LINE_NUM,
                                        REQUISITION_TYPE,
                                        --category_id,
                                        unit_price,
                                        quantity,
                                        destination_organization_id,
                                        -- DESTINATION_SUBINVENTORY,
                                        SOURCE_ORGANIZATION_ID,
                                        deliver_to_location_id,
                                        deliver_to_requestor_id,
                                        item_description,
                                        item_id,
                                        BATCH_ID,
                                        req_number_segment1,
                                        NEED_BY_DATE,
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
                                        dist_attribute_category,
                                        distribution_attribute1,
                                        distribution_attribute2,
                                        distribution_attribute3,
                                        distribution_attribute4,
                                        distribution_attribute5,
                                        distribution_attribute6,
                                        distribution_attribute7,
                                        distribution_attribute8,
                                        distribution_attribute9,
                                        distribution_attribute10,
                                        distribution_attribute11,
                                        distribution_attribute12,
                                        distribution_attribute13,
                                        distribution_attribute14,
                                        distribution_attribute15,
                                        creation_date,
                                        created_by,
                                        LAST_UPDATE_LOGIN,
                                        LAST_UPDATED_BY,
                                        LAST_UPDATE_DATE,
                                        REQUEST_ID)
                                 VALUES (
                                            'INVENTORY',
                                            gtt_req_interface_tab (i).NEW_ORG_ID,
                                            NVL (
                                                gtt_req_interface_tab (i).destination_type_code,
                                                'INVENTORY'),
                                            NVL (
                                                gtt_req_interface_tab (i).authorization_status,
                                                'APPROVED'),
                                            gtt_req_interface_tab (i).new_preparer_id,
                                            gtt_req_interface_tab (i).new_charge_account_id,
                                            'INVENTORY', --gtt_req_interface_tab (i).source_type_code,
                                            gtt_req_interface_tab (i).UNIT_MEAS_LOOKUP_CODE,
                                            gtt_req_interface_tab (i).new_line_type_id,
                                            --gtt_req_interface_tab (i).new_category_id,
                                            --gtt_req_interface_tab (i).LINE_NUM,
                                            gtt_req_interface_tab (i).REQUISITION_TYPE,
                                            gtt_req_interface_tab (i).unit_price,
                                            gtt_req_interface_tab (i).quantity,
                                            gtt_req_interface_tab (i).new_dest_organization_id, --127,
                                            --                            UPPER (
                                            --                               gtt_req_interface_tab (i).DESTINATION_SUBINVENTORY), ----added on 26th may
                                            gtt_req_interface_tab (i).new_source_organization_id, --125
                                            gtt_req_interface_tab (i).new_deliver_to_location_id, --219
                                            gtt_req_interface_tab (i).NEW_REQUESTOR_ID,
                                            gtt_req_interface_tab (i).item_description,
                                            gtt_req_interface_tab (i).NEW_INVENTORY_ITEM_ID,
                                            --gtt_req_interface_tab (i).worker_batch_number,---commented on 28thmay
                                            p_batch_id, --existing seq in drop ship
                                            gtt_req_interface_tab (i).REQUISiTION_NUMBER,
                                            gtt_req_interface_tab (i).NEED_BY_DATE,
                                            NVL (
                                                gtt_req_interface_tab (i).REQ_HEADER_ATTRIBUTE_CATEGORY,
                                                'REQ_CONVERSION'),
                                            gtt_req_interface_tab (i).REQ_HEADER_ATTRIBUTE1,
                                            gtt_req_interface_tab (i).REQ_HEADER_ATTRIBUTE2,
                                            gtt_req_interface_tab (i).REQ_HEADER_ATTRIBUTE3,
                                            gtt_req_interface_tab (i).REQ_HEADER_ATTRIBUTE4,
                                            gtt_req_interface_tab (i).REQ_HEADER_ATTRIBUTE5,
                                            gtt_req_interface_tab (i).REQ_HEADER_ATTRIBUTE6,
                                            gtt_req_interface_tab (i).REQ_HEADER_ATTRIBUTE7,
                                            gtt_req_interface_tab (i).REQ_HEADER_ATTRIBUTE8,
                                            gtt_req_interface_tab (i).REQ_HEADER_ATTRIBUTE9,
                                            gtt_req_interface_tab (i).REQ_HEADER_ATTRIBUTE10,
                                            gtt_req_interface_tab (i).REQ_HEADER_ATTRIBUTE11,
                                            gtt_req_interface_tab (i).REQ_HEADER_ATTRIBUTE12,
                                            gtt_req_interface_tab (i).REQ_HEADER_ATTRIBUTE13,
                                            gtt_req_interface_tab (i).REQ_HEADER_ATTRIBUTE14,
                                            gtt_req_interface_tab (i).OLD_REQUISITION_HEADER_ID,
                                            NVL (
                                                'REQ_CONVERSION',
                                                gtt_req_interface_tab (i).REQ_LINE_ATTRIBUTE_CATEGORY),
                                            gtt_req_interface_tab (i).REQ_LINE_ATTRIBUTE1,
                                            gtt_req_interface_tab (i).REQ_LINE_ATTRIBUTE2,
                                            gtt_req_interface_tab (i).REQ_LINE_ATTRIBUTE3,
                                            gtt_req_interface_tab (i).REQ_LINE_ATTRIBUTE4,
                                            gtt_req_interface_tab (i).REQ_LINE_ATTRIBUTE5,
                                            gtt_req_interface_tab (i).REQ_LINE_ATTRIBUTE6,
                                            gtt_req_interface_tab (i).REQ_LINE_ATTRIBUTE7,
                                            gtt_req_interface_tab (i).REQ_LINE_ATTRIBUTE8,
                                            gtt_req_interface_tab (i).REQ_LINE_ATTRIBUTE9,
                                            gtt_req_interface_tab (i).REQ_LINE_ATTRIBUTE10,
                                            gtt_req_interface_tab (i).REQ_LINE_ATTRIBUTE11,
                                            gtt_req_interface_tab (i).SHIPMENT_NUM,
                                            gtt_req_interface_tab (i).line_num,
                                            gtt_req_interface_tab (i).PO_LINE_ID,
                                            gtt_req_interface_tab (i).REQUISITION_LINE_ID,
                                            gtt_req_interface_tab (i).REQ_DIST_ATTRIBUTE_CATEGORY,
                                            gtt_req_interface_tab (i).REQ_DIST_ATTRIBUTE1,
                                            gtt_req_interface_tab (i).REQ_DIST_ATTRIBUTE2,
                                            gtt_req_interface_tab (i).REQ_DIST_ATTRIBUTE3,
                                            gtt_req_interface_tab (i).REQ_DIST_ATTRIBUTE4,
                                            gtt_req_interface_tab (i).REQ_DIST_ATTRIBUTE5,
                                            gtt_req_interface_tab (i).REQ_DIST_ATTRIBUTE6,
                                            gtt_req_interface_tab (i).REQ_DIST_ATTRIBUTE7,
                                            gtt_req_interface_tab (i).REQ_DIST_ATTRIBUTE8,
                                            gtt_req_interface_tab (i).REQ_DIST_ATTRIBUTE9,
                                            gtt_req_interface_tab (i).REQ_DIST_ATTRIBUTE10,
                                            gtt_req_interface_tab (i).REQ_DIST_ATTRIBUTE11,
                                            gtt_req_interface_tab (i).REQ_DIST_ATTRIBUTE12,
                                            gtt_req_interface_tab (i).REQ_DIST_ATTRIBUTE13,
                                            gtt_req_interface_tab (i).REQ_DIST_ATTRIBUTE14,
                                            gtt_req_interface_tab (i).REQ_DIST_ATTRIBUTE15,
                                            --gd_sysdate,
                                            gtt_req_interface_tab (i).IR_creation_date,
                                            gn_user_id,
                                            gn_login_id,
                                            gn_user_id,
                                            gd_sysdate,
                                            fnd_global.conc_request_id);

                    COMMIT;

                    SELECT COUNT (1)
                      INTO ln_count
                      FROM po_requisitions_interface_all
                     WHERE request_id = fnd_global.conc_request_id; ---added on 28thmay

                    fnd_file.put_line (fnd_file.LOG, 'Count ' || ln_count);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        SELECT COUNT (1)
                          INTO ln_count
                          FROM po_requisitions_interface_all
                         WHERE request_id = fnd_global.conc_request_id; ---added on 28thmay

                        fnd_file.put_line (fnd_file.LOG,
                                           'Count2 ' || ln_count);

                        IF SQLCODE = -24381
                        THEN
                            gc_code_pointer   :=
                                'Exception while Loading data into interface table';

                            FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                            LOOP
                                XXD_common_utils.record_error (
                                    'PORQL',
                                    gn_org_id,
                                    'Deckers PO Requisition Conversion',
                                       'Error code '
                                    || SQLERRM (
                                           -(SQL%BULK_EXCEPTIONS (indx).ERROR_CODE)),
                                    DBMS_UTILITY.format_error_backtrace,
                                    gn_user_id,
                                    gn_req_id,
                                    'Code pointer : ' || gc_code_pointer,
                                    'XXD_PO_REQUISITION_CONV_STG_T');
                            END LOOP;
                        ELSE
                            XXD_common_utils.record_error (
                                'PORQL',
                                gn_org_id,
                                'Deckers PO Requisition Conversion',
                                SQLERRM,
                                DBMS_UTILITY.format_error_backtrace,
                                gn_user_id,
                                gn_req_id,
                                'Code pointer : ' || gc_code_pointer,
                                'XXD_PO_REQUISITION_CONV_STG_T');
                        END IF;
                END;
            --fnd_file.put_line (fnd_file.LOG, 'Test5');
            ELSE
                --fnd_file.put_line (fnd_file.LOG, 'Test6');
                EXIT;
            END IF;

            --fnd_file.put_line (fnd_file.LOG, 'Test7');

            gtt_req_interface_tab.delete;
        END LOOP;

        CLOSE requisition_int_c;

        COMMIT;
    --fnd_file.put_line (fnd_file.LOG, 'Test8');
    /*      gc_code_pointer := 'After insert into Staging table';

          COMMIT;

          SELECT COUNT (*)
            INTO gn_inv_int
            FROM XXD_PO_REQUISITION_CONV_STG_T
           WHERE record_status = 'N';

          -- Writing counts to output file
          fnd_file.put_line (
             fnd_file.output,
             'S.No                   Entity           Total Records Extracted from 12.0.6 and loaded to 12.2.3 ');
          fnd_file.put_line (
             fnd_file.output,
             '----------------------------------------------------------------------------------------------');
          fnd_file.put_line (
             fnd_file.output,
                '1                    '
             || RPAD ('XXD_PO_REQUISITION_CONV_STG_T', 40, ' ')
             || '   '
             || gn_inv_int); */
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'OTHERS Exception while Insert into XXD_PO_REQUISITION_CONV_STG_T Table');


            XXD_common_utils.record_error (
                'PORQL',
                gn_org_id,
                'Deckers PO Requisition Conversion',
                DBMS_UTILITY.format_error_backtrace,
                gn_user_id,
                gn_req_id,
                'Code pointer : ' || gc_code_pointer,
                'XXD_PO_REQUISITION_CONV_STG_T');


            x_retcode   := 2;
    END INTERFACE_REQUISITION_PROC;



    /******************************************************
     * Procedure: XXD_PO_REQUISITION_MAIN_PRC
     *
     * Synopsis: This procedure will call we be called by the concurrent program
     * Design:
     *
     * Notes:
     *
     * PARAMETERS:
     *   OUT: (x_retcode  Number
     *   OUT: x_errbuf  Varchar2
     *   IN    : p_process  varchar2
     *   IN    : p_debug  varchar2
     *
     * Return Values:
     * Modifications:
     *
     ******************************************************/

    PROCEDURE XXD_PO_REQUISITION_MAIN_PRC (x_retcode OUT NUMBER, x_errbuf OUT VARCHAR2, p_process IN VARCHAR2
                                           , p_no_of_batches IN NUMBER, p_debug IN VARCHAR2, p_scenario IN VARCHAR2)
    IS
        x_errcode                     VARCHAR2 (500);
        x_errmsg                      VARCHAR2 (500);
        lc_debug_flag                 VARCHAR2 (1);
        ln_eligible_records           NUMBER;
        ln_total_valid_records        NUMBER;
        ln_total_error_records        NUMBER;
        ln_total_load_records         NUMBER;
        ln_batch_low                  NUMBER;
        ln_total_batch                NUMBER;
        lc_phase                      VARCHAR2 (100);
        lc_status                     VARCHAR2 (100);
        lc_dev_phase                  VARCHAR2 (100);
        lc_dev_status                 VARCHAR2 (100);
        lc_message                    VARCHAR2 (100);
        lb_wait_for_request           BOOLEAN := FALSE;
        lb_get_request_status         BOOLEAN := FALSE;
        request_submission_failed     EXCEPTION;
        request_completion_abnormal   EXCEPTION;

        CURSOR get_max_batch_no IS
            SELECT MAX (worker_batch_number)
              FROM XXD_PO_REQUISITION_CONV_STG_T
             WHERE     record_status IN ('N', 'E')
                   AND SCENARIO = NVL (p_scenario, SCENARIO);

        CURSOR get_max_valid_batch_no IS
            SELECT MAX (worker_batch_number)
              FROM XXD_PO_REQUISITION_CONV_STG_T
             WHERE     record_status IN ('V')
                   AND SCENARIO = NVL (p_scenario, SCENARIO);


        --AND REQUISTION_NUMBER = '10'--AND record_status = 'V'

        --AND   OLD_REQUISITION_HEADER_ID = 20054
        --      and DISTRIBUTION_ID = 1097222


        ln_batch_no                   NUMBER;

        ln_counter                    NUMBER;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id                      request_table;

        ln_request_id                 NUMBER;
        ln_batch_id                   NUMBER;
        ln_loop_counter               NUMBER := 1;

        /*   lc_phase VARCHAR2(50);
                                      lc_status VARCHAR2(50);
                                      lc_dev_phase VARCHAR2(50);
                                      lc_dev_status VARCHAR2(50);
                                      lc_message VARCHAR2(50); */


        /*CURSOR get_distinct_org_id_c
              IS
                 SELECT DISTINCT org_id FROM po_requisitions_interface_all;*/
        --commented on 02 jun

        CURSOR get_distinct_org_id_c IS
            SELECT DISTINCT xpr.new_org_id
              FROM XXD_PO_REQUISITION_CONV_STG_T xpr
             WHERE xpr.scenario = p_scenario;            -------added on 02jun

        CURSOR get_distinct_batch_id_c (P_request_id NUMBER)
        IS
            SELECT DISTINCT prla.org_id, PRLA.BATCH_ID
              FROM po_requisitions_interface_all prla
             WHERE 1 = 1 AND REQUEST_ID = P_request_id;  -------added on 02jun



        ln_org_id                     NUMBER;
        ln_proc_int                   NUMBER;
        ln_error_int                  NUMBER;
        ln_count                      NUMBER;

        CURSOR get_import_error_c IS
            SELECT req_number_segment1, COLUMN_NAME, COLUMN_VALUE,
                   error_message
              FROM po_interface_errors pie, po_requisitions_interface_all pri
             WHERE     pie.INTERFACE_TRANSACTION_ID = pri.transaction_id
                   AND pri.request_id IN
                           (SELECT DISTINCT request_id
                              FROM XXD_PO_REQUISITION_CONV_STG_T
                             WHERE     1 = 1
                                   AND SCENARIO = NVL (p_scenario, SCENARIO));

        lcu_get_import_error_c        Get_import_error_c%ROWTYPE;



        CURSOR get_req_num_c IS
            SELECT REQUISITION_NUMBER, LINE_NUM, ITEM_NUMBER,
                   QUANTITY, NEED_BY_DATE, QUANTITY_RECEIVE
              FROM XXD_PO_REQUISITION_CONV_STG_T
             WHERE 1 = 1 AND SCENARIO = NVL (p_scenario, SCENARIO);

        lcu_get_req_num_c             get_req_num_c%ROWTYPE;


        CURSOR get_req_num_c1 IS
            SELECT XPC.REQUISITION_NUMBER,
                   XPC.LINE_NUM,
                   XPC.ITEM_NUMBER,
                   DESTINATION_ORGANIZATION_NAME
                       OLD_DEST_ORG,
                   SOURCE_ORGANIZATION_NAME
                       OLD_SOURCE_ORG,
                   (SELECT organization_code
                      FROM org_organization_definitions
                     WHERE organization_id = NEW_DEST_ORGANIZATION_ID)
                       DEST_ORG,
                   (SELECT organization_code
                      FROM org_organization_definitions
                     WHERE organization_id = NEW_SOURCE_ORGANIZATION_ID)
                       SOURCE_ORG,
                   PREPARER,
                   REQUESTOR,
                   USEFUL_INFO3
              FROM xxd_error_log_t XEL, XXD_PO_REQUISITION_CONV_STG_T XPC
             WHERE     XEL.request_id = XPC.request_id
                   AND TO_CHAR (XPC.DISTRIBUTION_ID) = XEL.USEFUL_INFO4
                   AND SCENARIO = NVL (p_scenario, SCENARIO);

        lcu_get_req_num_c1            get_req_num_c1%ROWTYPE;
    BEGIN
        gc_debug_flag   := p_debug;


        -- EXTRACT
        IF p_process = 'EXTRACT'
        THEN
            gc_code_pointer   := 'Calling Extract process  ';

            IF p_debug = 'Y'
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Code Pointer: ' || gc_code_pointer);
            END IF;

            -- Calling Extract procedure



            EXTRACT_REQUISITION_PROC (p_no_of_batches, p_scenario);


            fnd_file.put_line (
                fnd_file.OUTPUT,
                '                                                 ');


            fnd_file.put_line (
                fnd_file.OUTPUT,
                'Deckers PO Requisition Conversion  Extract Report');
            fnd_file.put_line (
                fnd_file.OUTPUT,
                '-------------------------------------------------');
            fnd_file.put_line (fnd_file.OUTPUT, '');
            fnd_file.put_line (
                fnd_file.OUTPUT,
                   RPAD ('Requisition Number', 20)
                || RPAD ('Line no', 10)
                || RPAD ('Item ', 20)
                || RPAD ('QUANTITY ', 30)
                || RPAD ('QTY_RECEIVE ', 30)
                || RPAD ('need_by_date ', 30));
            fnd_file.put_line (
                fnd_file.OUTPUT,
                RPAD (
                    '*******************************************************************************************************************************',
                    120));

            OPEN get_req_num_c;

            LOOP
                FETCH get_req_num_c INTO lcu_get_req_num_c;

                EXIT WHEN get_req_num_c%NOTFOUND;

                fnd_file.put_line (
                    fnd_file.OUTPUT,
                       RPAD (lcu_get_req_num_c.REQUISITION_NUMBER, 20)
                    || RPAD (lcu_get_req_num_c.LINE_NUM, 10)
                    || RPAD (lcu_get_req_num_c.ITEM_NUMBER, 20)
                    || RPAD (lcu_get_req_num_c.QUANTITY, 30)
                    || RPAD (NVL (lcu_get_req_num_c.QUANTITY_RECEIVE, 0),
                             30,
                             ' ')
                    || RPAD (SUBSTR (lcu_get_req_num_c.NEED_BY_DATE, 1, 30),
                             30));
            END LOOP;

            CLOSE get_req_num_c;
        ELSIF p_process = 'VALIDATE'
        THEN
            gc_code_pointer   := 'Calling Validate process  ';


            IF p_debug = 'Y'
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Code Pointer: ' || gc_code_pointer);
            END IF;

            OPEN get_max_batch_no;

            FETCH get_max_batch_no INTO ln_batch_no;

            CLOSE get_max_batch_no;

            IF ln_batch_no IS NOT NULL
            THEN
                gc_code_pointer   :=
                    'Calling Child requests in Validate process  ';

                FOR i IN 1 .. ln_batch_no
                LOOP
                    -- Check if each batch has eligible recors ,if so launch worker program

                    fnd_file.put_line (fnd_file.LOG, 'Test1');

                    SELECT COUNT (*)
                      INTO ln_counter
                      FROM XXD_PO_REQUISITION_CONV_STG_T
                     WHERE     record_status IN ('N', 'E')
                           AND worker_batch_number = i
                           AND SCENARIO = NVL (p_scenario, SCENARIO);

                    fnd_file.put_line (fnd_file.LOG, 'Test2');

                    IF ln_counter > 0
                    THEN
                        gc_code_pointer   :=
                            'Calling fnd_request.submit_request in Validate process  ';

                        ln_request_id   :=
                            fnd_request.submit_request (
                                application   => 'XXDCONV',
                                program       => 'XXD_PO_REQ_CONV_VAL_WORK',
                                description   =>
                                    'Deckers PO Requistion Conversion - Validate',
                                start_time    => gd_sysdate,
                                sub_request   => NULL,
                                argument1     => i,
                                argument2     => p_debug,
                                argument3     => p_scenario);

                        fnd_file.put_line (fnd_file.LOG, 'Test3');

                        IF ln_request_id > 0
                        THEN
                            COMMIT;
                            l_req_id (ln_loop_counter)   := ln_request_id;
                            ln_loop_counter              :=
                                ln_loop_counter + 1;
                        /*  ELSE
                             ROLLBACK; */
                        END IF;
                    END IF;
                END LOOP;

                fnd_file.put_line (fnd_file.LOG, 'Test4');

                gc_code_pointer   :=
                    'Waiting for child requests in Validate process  ';



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
                                    'Calling fnd_concurrent.wait_for_request in  Validate process  ';

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
                        /*ELSE
                           RAISE request_submission_failed; */
                        END IF;
                    EXCEPTION
                        /*    WHEN request_submission_failed
                            THEN
                               print_log_prc (
                                  p_debug,
                                     'Child Concurrent request submission failed - '
                                  || ' XXD_AP_INV_CONV_VAL_WORK - '
                                  || ln_request_id
                                  || ' - '
                                  || SQLERRM);
                            WHEN request_completion_abnormal
                            THEN
                               print_log_prc (
                                  p_debug,
                                     'Submitted request completed with error'
                                  || ' XXD_AP_INVOICE_CONV_VAL_WORK - '
                                  || ln_request_id); */
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Code pointer ' || gc_code_pointer);

                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error message ' || SUBSTR (SQLERRM, 0, 240));
                    END;
                END LOOP;
            END IF;

            COMMIT;

            fnd_file.put_line (fnd_file.LOG, 'Test5');

            --fnd_file.put_line (                     fnd_file.LOG,'Test1');

            fnd_file.put_line (
                fnd_file.OUTPUT,
                '                                                 ');


            fnd_file.put_line (
                fnd_file.OUTPUT,
                'Deckers PO Requisition Conversion  Error Report');
            fnd_file.put_line (
                fnd_file.OUTPUT,
                '-------------------------------------------------');
            --fnd_file.put_line (                     fnd_file.LOG,'Test2');
            fnd_file.put_line (fnd_file.OUTPUT, '');
            fnd_file.put_line (
                fnd_file.OUTPUT,
                   RPAD ('Req ', 10)
                || RPAD ('Line ', 10)
                || RPAD ('Item Number', 20)
                || RPAD ('Old Dest ', 10)
                || RPAD ('Old Source ', 12)
                || RPAD ('Dest ', 10)
                || RPAD ('Source ', 10)
                --|| RPAD ('Preparer ', 30)
                --|| RPAD ('Requestor ', 30)
                || RPAD ('Error message1', 30));

            fnd_file.put_line (
                fnd_file.OUTPUT,
                RPAD (
                    '*************************************************************************************************************************************************************************',
                    120));

            fnd_file.put_line (fnd_file.LOG, 'Test6');

            OPEN get_req_num_c1;

            LOOP
                FETCH get_req_num_c1 INTO lcu_get_req_num_c1;

                --fnd_file.put_line (                     fnd_file.LOG,'Test4');


                EXIT WHEN get_req_num_c1%NOTFOUND;

                --fnd_file.put_line (                     fnd_file.LOG,'Test5');

                fnd_file.put_line (
                    fnd_file.OUTPUT,
                       RPAD (lcu_get_req_num_c1.REQUISITION_NUMBER, 10)
                    || RPAD (lcu_get_req_num_c1.LINE_NUM, 10)
                    || RPAD (SUBSTR (lcu_get_req_num_c1.ITEM_NUMBER, 1, 20),
                             20)
                    || RPAD (SUBSTR (lcu_get_req_num_c1.OLD_DEST_ORG, 1, 3),
                             10)
                    || RPAD (
                           SUBSTR (lcu_get_req_num_c1.OLD_SOURCE_ORG, 1, 3),
                           12)
                    || RPAD (
                           SUBSTR (NVL (lcu_get_req_num_c1.DEST_ORG, ' '),
                                   1,
                                   3),
                           10)
                    || RPAD (
                           SUBSTR (NVL (lcu_get_req_num_c1.SOURCE_ORG, ' '),
                                   1,
                                   3),
                           10)
                    --|| RPAD (SUBSTR (lcu_get_req_num_c1.PREPARER, 1, 30),30)
                    --|| RPAD (SUBSTR (lcu_get_req_num_c1.REQUESTOR, 1, 30),30)
                    || RPAD (
                           SUBSTR (lcu_get_req_num_c1.USEFUL_INFO3, 1, 150),
                           100));
            --fnd_file.put_line (                     fnd_file.LOG,'Test6');
            END LOOP;

            CLOSE get_req_num_c1;

            fnd_file.put_line (fnd_file.LOG, 'Test7');
        ELSIF p_process = 'LOAD'
        THEN
            gc_code_pointer   := 'Calling Load process  ';

            --DELETE po_requisitions_interface_all;

            IF p_debug = 'Y'
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Code Pointer: ' || gc_code_pointer);
            END IF;


            OPEN get_max_valid_batch_no;

            FETCH get_max_valid_batch_no INTO ln_batch_no;

            CLOSE get_max_valid_batch_no;



            gc_code_pointer   := 'Calling Child requests in Load process  ';
            fnd_file.put_line (fnd_file.LOG, 'Batch no ' || ln_batch_no);

            IF ln_batch_no IS NOT NULL
            THEN
                /*FOR i IN 1 .. ln_batch_no
                LOOP
                   -- Check if each batch has eligible recors ,if so launch worker program

                   fnd_file.put_line (fnd_file.LOG, 'i :  ' || i);

                   SELECT COUNT (*)
                     INTO ln_counter
                     FROM XXD_PO_REQUISITION_CONV_STG_T
                    WHERE     record_status IN ('V')
                          AND worker_batch_number = i
                          AND SCENARIO = NVL (p_scenario, SCENARIO);

                   IF ln_counter > 0
                   THEN
                      gc_code_pointer :=
                         'Calling fnd_request.submit_request in Load process  ';

                      ln_request_id :=
                         fnd_request.submit_request (
                            application   => 'XXDCONV',
                            program       => 'XXD_PO_REQ_CONV_LOAD_WORK',
                            description   => 'Deckers PO Requistion Conversion - Load',
                            start_time    => gd_sysdate,
                            sub_request   => NULL,
                            argument1     => i,
                            argument2     => p_debug,
                            argument3     => p_scenario);


                      IF ln_request_id > 0
                      THEN
                         COMMIT;
                         l_req_id (ln_loop_counter) := ln_request_id;
                         ln_loop_counter := ln_loop_counter + 1;
                      --  ELSE
                           --ROLLBACK;
                      END IF;
                   END IF;
                END LOOP;*/
                ---02 jun


                OPEN get_distinct_org_id_c;

                LOOP
                    ln_org_id   := NULL;

                    FETCH get_distinct_org_id_c INTO ln_org_id;

                    EXIT WHEN get_distinct_org_id_c%NOTFOUND;

                    SELECT COUNT (*)
                      INTO ln_counter
                      FROM XXD_PO_REQUISITION_CONV_STG_T
                     WHERE     record_status IN ('V')
                           AND new_org_id = ln_org_id
                           AND SCENARIO = NVL (p_scenario, SCENARIO);

                    IF ln_counter > 0
                    THEN
                        gc_code_pointer   :=
                            'Calling fnd_request.submit_request in Load process  ';

                        ln_request_id   :=
                            fnd_request.submit_request (
                                application   => 'XXDCONV',
                                program       => 'XXD_PO_REQ_CONV_LOAD_WORK',
                                description   =>
                                    'Deckers PO Requistion Conversion - Load',
                                start_time    => gd_sysdate,
                                sub_request   => NULL,
                                argument1     => ln_org_id,
                                argument2     => p_debug,
                                argument3     => p_scenario);


                        IF ln_request_id > 0
                        THEN
                            COMMIT;
                            l_req_id (ln_loop_counter)   := ln_request_id;
                            ln_loop_counter              :=
                                ln_loop_counter + 1;
                        /*  ELSE
                             ROLLBACK; */
                        END IF;
                    END IF;
                END LOOP;


                CLOSE get_distinct_org_id_c;



                --fnd_file.put_line (fnd_file.LOG, 'Test1');

                gc_code_pointer   :=
                    'Waiting for child requests in Load process  ';

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
                                    'Calling fnd_concurrent.wait_for_request in  Load process  ';

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
                        /*ELSE
                           RAISE request_submission_failed; */
                        END IF;
                    EXCEPTION
                        /*    WHEN request_submission_failed
                            THEN
                               print_log_prc (
                                  p_debug,
                                     'Child Concurrent request submission failed - '
                                  || ' XXD_AP_INV_CONV_VAL_WORK - '
                                  || ln_request_id
                                  || ' - '
                                  || SQLERRM);
                            WHEN request_completion_abnormal
                            THEN
                               print_log_prc (
                                  p_debug,
                                     'Submitted request completed with error'
                                  || ' XXD_AP_INVOICE_CONV_VAL_WORK - '
                                  || ln_request_id); */
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Code pointer ' || gc_code_pointer);

                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error message ' || SUBSTR (SQLERRM, 1, 240));
                    END;
                END LOOP;

                COMMIT;
            END IF;


            SELECT COUNT (1) INTO ln_count FROM po_requisitions_interface_all;

            fnd_file.put_line (fnd_file.LOG, 'Count1 ' || ln_count);

            --fnd_file.put_line (fnd_file.LOG, 'Test2');

            --Calling  Requisition Import

            gc_code_pointer   :=
                'Calling Child requests in Requisition Import process  ';

            --fnd_file.put_line (fnd_file.LOG, 'Test3');


            ln_loop_counter   := 0;

            /*OPEN get_distinct_org_id_c;

            LOOP
               ln_org_id := NULL;

               FETCH get_distinct_org_id_c INTO ln_org_id;

               EXIT WHEN get_distinct_org_id_c%NOTFOUND;*/
            --commented on 02 jun
            fnd_file.put_line (fnd_file.LOG, 'Testing ' || ln_count);

            FOR rec IN l_req_id.FIRST .. l_req_id.LAST
            LOOP
                OPEN get_distinct_batch_id_c (l_req_id (rec));

                LOOP
                    ln_org_id   := NULL;

                    FETCH get_distinct_batch_id_c INTO ln_org_id, ln_batch_id;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Inside get_distinct_batch_id_c cursor  ');

                    EXIT WHEN get_distinct_batch_id_c%NOTFOUND;


                    --fnd_global.APPS_INITIALIZE (0, 50721, 201);

                    --fnd_file.put_line (fnd_file.LOG, 'Org id ' || ln_org_id);


                    --fnd_global.APPS_INITIALIZE (l_user_id, l_resp_id, l_appl_id);
                    MO_GLOBAL.init ('PO');
                    mo_global.set_policy_context ('S', ln_org_id);
                    FND_REQUEST.SET_ORG_ID (ln_org_id);
                    --DBMS_APPLICATION_INFO.set_client_info (ln_org_id);

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Org id ' || mo_global.get_current_org_id);

                    ln_request_id   :=
                        fnd_request.submit_request (
                            application   => 'PO',
                            PROGRAM       => 'REQIMPORT',
                            description   => 'Requisition Import',
                            start_time    => SYSDATE,
                            sub_request   => FALSE,
                            argument1     => NULL,
                            argument2     => ln_batch_id,
                            argument3     => 'ALL',
                            argument4     => NULL,
                            argument5     => 'N',
                            argument6     => 'N');


                    IF ln_request_id > 0
                    THEN
                        COMMIT;
                        l_req_id (ln_loop_counter)   := ln_request_id;
                        ln_loop_counter              := ln_loop_counter + 1;
                    /*  ELSE
                         ROLLBACK; */
                    END IF;
                END LOOP;

                CLOSE get_distinct_batch_id_c;               --added on 02 jun
            END LOOP;

            --CLOSE get_distinct_org_id_c; --commented on 02 jun

            --fnd_file.put_line (fnd_file.LOG, 'Test4');


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
                        /*ELSE
                           RAISE request_submission_failed; */
                        END IF;
                    EXCEPTION
                        /*    WHEN request_submission_failed
                            THEN
                               print_log_prc (
                                  p_debug,
                                     'Child Concurrent request submission failed - '
                                  || ' XXD_AP_INV_CONV_VAL_WORK - '
                                  || ln_request_id
                                  || ' - '
                                  || SQLERRM);
                            WHEN request_completion_abnormal
                            THEN
                               print_log_prc (
                                  p_debug,
                                     'Submitted request completed with error'
                                  || ' XXD_AP_INVOICE_CONV_VAL_WORK - '
                                  || ln_request_id); */
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Code pointer ' || gc_code_pointer);

                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error message ' || SUBSTR (SQLERRM, 1, 240));
                    END;
                END LOOP;
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                    'no data inserted into req interface table');
            END IF;

            COMMIT;

            --fnd_file.put_line (fnd_file.LOG, 'Test5');

            --Updating record status
            UPDATE XXD_PO_REQUISITION_CONV_STG_T XPRC
               SET RECORD_STATUS   = 'P'
             WHERE     EXISTS
                           (SELECT 1
                              FROM PO_REQUISiTION_HEADERS_ALL PHA
                             WHERE     SEGMENT1 = XPRC.REQUISiTION_NUMBER
                                   AND ORG_ID = XPRC.NEW_ORG_ID
                                   AND SCENARIO = NVL (p_scenario, SCENARIO))
                   AND record_status = 'V'
                   AND SCENARIO = NVL (p_scenario, 'X');



            UPDATE XXD_PO_REQUISITION_CONV_STG_T XPRC
               SET RECORD_STATUS   = 'LE'
             WHERE     NOT EXISTS
                           (SELECT 1
                              FROM PO_REQUISiTION_HEADERS_ALL PHA
                             WHERE     SEGMENT1 = XPRC.REQUISiTION_NUMBER
                                   AND ORG_ID = XPRC.NEW_ORG_ID)
                   AND SCENARIO = NVL (p_scenario, SCENARIO)
                   AND record_status = 'V';

            COMMIT;

            --fnd_file.put_line (fnd_file.LOG, 'Test6');

            gc_code_pointer   := 'After insert into Staging table';

            COMMIT;

            SELECT COUNT (*)
              INTO ln_proc_int
              FROM XXD_PO_REQUISITION_CONV_STG_T
             WHERE     record_status = 'P'
                   AND SCENARIO = NVL (p_scenario, SCENARIO);


            SELECT COUNT (*)
              INTO ln_error_int
              FROM XXD_PO_REQUISITION_CONV_STG_T
             WHERE     record_status = 'LE'
                   AND SCENARIO = NVL (p_scenario, SCENARIO);

            IF NVL (ln_error_int, 0) > 0
            THEN
                x_retcode   := 1;
            ELSIF NVL (ln_proc_int, 0) = 0
            THEN
                x_retcode   := 2;
            END IF;

            --fnd_file.put_line (fnd_file.LOG, 'Test7');
            -- Writing Counts to output file.

            fnd_file.put_line (fnd_file.OUTPUT,
                               'Deckers PO Requisition Conversion  ');
            fnd_file.put_line (
                fnd_file.OUTPUT,
                '-------------------------------------------------');

            fnd_file.put_line (
                fnd_file.OUTPUT,
                   'Total no records Processed in XXD_PO_REQUISITION_CONV_STG_T Table '
                || ln_proc_int);
            fnd_file.put_line (
                fnd_file.OUTPUT,
                   'Total no records Errored in Load XXD_PO_REQUISITION_CONV_STG_T Table '
                || ln_error_int);



            fnd_file.put_line (fnd_file.output, '');
            fnd_file.put_line (
                fnd_file.output,
                   RPAD ('Requisition Number', 50)    --|| RPAD ('Column', 20)
                --|| RPAD ('Value', 20)
                || RPAD ('Error message ', 500));
            fnd_file.put_line (
                fnd_file.output,
                RPAD (
                    '*******************************************************************************************************************************',
                    120));

            OPEN get_import_error_c;

            LOOP
                FETCH get_import_error_c INTO lcu_get_import_error_c;

                fnd_file.put_line (
                    fnd_file.output,
                       RPAD (lcu_get_import_error_c.req_number_segment1, 50) --|| RPAD (lcu_get_import_error_c.COLUMN_NAME, 20)
                    --|| RPAD (lcu_get_import_error_c.COLUMN_VALUE, 20)
                    || RPAD (lcu_get_import_error_c.error_message, 500));


                EXIT WHEN get_import_error_c%NOTFOUND;
            END LOOP;

            CLOSE get_import_error_c;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Code Pointer: ' || gc_code_pointer);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Messgae: '
                || 'Unexpected error in PO Requisition Conversion '
                || SUBSTR (SQLERRM, 1, 300));
            fnd_file.put_line (fnd_file.LOG, '');
            x_retcode   := 2;
            x_errbuf    :=
                   'Error Message in XXD_PO_REQUISITION_MAIN_PRC '
                || SUBSTR (SQLERRM, 1, 300);
    END XXD_PO_REQUISITION_MAIN_PRC;



    PROCEDURE CREATE_PROGRESS_ORDER (x_retcode OUT NUMBER, x_errbuf OUT VARCHAR2, p_scenario IN VARCHAR2)
    AS
        CURSOR c_get_line_notf_act --(      p_order_number NUMBER)
                                   IS
            SELECT TO_NUMBER (st.item_key) line_id, oha.header_id header_id, wpa.activity_name
              FROM apps.wf_item_activity_statuses st, apps.wf_process_activities wpa, apps.oe_order_lines_all ola,
                   apps.oe_order_headers_all oha, hr_operating_units hou
             --XXD_PO_REQUISITION_CONV_STG_T XPRC
             WHERE     wpa.instance_id = st.process_activity
                   AND st.item_type = 'OEOL'
                   AND wpa.activity_name IN ('LINE_SCHEDULING', 'SCHEDULING_ELIGIBLE', 'CREATE_SUPPLY_ORDER_ELIGIBLE',
                                             'BOOK_WAIT_FOR_H')
                   AND st.activity_status = 'NOTIFIED'
                   AND st.item_key = ola.line_id
                   AND hou.name = 'Deckers Macau OU'
                   AND oha.org_id = hou.organization_id
                   AND ola.header_id = oha.header_id
                   AND EXISTS
                           (SELECT 1
                              FROM XXD_PO_REQUISITION_CONV_STG_T XPRC
                             WHERE     XPRC.REQUISITION_NUMBER =
                                       oha.ORIG_SYS_DOCUMENT_REF
                                   AND XPRC.record_status = 'P'
                                   AND SCENARIO = P_SCENARIO --IN ('APAC', 'EUROPE') --COMMENTED ON 02 JUN
                                                            );

        l_retry                       BOOLEAN;
        p_lines                       BOOLEAN := FALSE;


        CURSOR cur_line IS
            SELECT DISTINCT OOIA.LINE_ID,
                            --PRLA.attribute15 old_IR_REQ_LINE_ID,
                            xprc.po_line_id,
                            xprc.REQUISITION_NUMBER,
                            xprc.purchase_req_number,
                            xprc.vendor_id,
                            xprc.vendor_site_id,
                            xprc.new_agent_id suggested_buyer_id,
                            XPRC.PR_CREATION_DATE,
                            XPRC.UNIT_PRICE,
                            XPRC.NEED_BY_DATE,
                            CASE
                                WHEN SCENARIO = 'EUROPE' THEN 'FACTORY'
                                ELSE XPRC.DESTINATION_SUBINVENTORY
                            END DESTINATION_SUBINVENTORY,
                            xprc.shipment_num
              FROM OE_ORDER_LINES_ALL OOIA, OE_ORDER_HEADERS_ALL OOHA, po_requisition_lines_all prla,
                   PO_REQUISITION_HEADERS_ALL PRHA, XXD_PO_REQUISITION_CONV_STG_T XPRC
             WHERE     1 = 1
                   AND XPRC.REQUISITION_NUMBER = OOHA.ORIG_SYS_DOCUMENT_REF
                   AND PRHA.SEGMENT1 = OOHA.ORIG_SYS_DOCUMENT_REF
                   AND PRHA.REQUISITION_HEADER_ID =
                       PRLA.REQUISITION_HEADER_ID
                   AND OOHA.HEADER_ID = OOIA.HEADER_ID
                   AND PRLA.REQUISITION_LINE_ID =
                       OOIA.SOURCE_DOCUMENT_LINE_ID
                   AND XPRC.PO_LINE_ID = PRLA.ATTRIBUTE14
                   AND XPRC.RECORD_STATUS = 'P'
                   AND SCENARIO = P_SCENARIO;

        -- IN ('APAC', 'EUROPE'); --COMMENTED ON 02 JUN

        REC_cur_line                  cur_line%ROWTYPE;

        /* CURSOR get_distinct_org_id_c
         IS
            SELECT DISTINCT org_id
              FROM po_requisitions_interface_all
             WHERE INTERFACE_SOURCE_CODE = 'CTO';*/

        -- ln_org_id             NUMBER;


        ln_batch_no                   NUMBER;

        -- ln_counter            NUMBER;

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
        v_count                       NUMBER := 0;
        v_line_count                  NUMBER;
        v_requisition_header_id       NUMBER;

        /*      TYPE request_table IS TABLE OF NUMBER
                                  INDEX BY BINARY_INTEGER;

         l_req_id              request_table;
         lc_phase              VARCHAR2 (10);

         ln_request_id         NUMBER;
         ln_loop_counter       NUMBER := 1;
         lc_dev_phase          VARCHAR2 (10);
         lc_dev_status         VARCHAR2 (10);
         lc_status             VARCHAR2 (1);

         lb_wait_for_request   BOOLEAN;*/
        lc_message                    VARCHAR2 (1);
        ln_user_id                    NUMBER := fnd_global.user_id;
        v_batch_id                    NUMBER;
    BEGIN
        FOR v_get_lines IN c_get_line_notf_act
        LOOP
            l_retry   := FALSE;
            p_lines   := FALSE;

            wf_engine.completeactivity ('OEOL', v_get_lines.line_id, v_get_lines.activity_name
                                        , NULL);
        END LOOP;



        wf_engine.background ('OEOL', NULL, NULL,
                              TRUE, FALSE, FALSE);


        /*   FOR v_get_lines IN c_get_line_notf_act
           LOOP
              l_retry := FALSE;
              p_lines := FALSE;

              wf_engine.completeactivity ('OEOL',
                                          v_get_lines.line_id,
                                          v_get_lines.activity_name,
                                          NULL);
           END LOOP;

           wf_engine.background ('OEOL',
                                 NULL,
                                 NULL,
                                 TRUE,
                                 FALSE,
                                 FALSE); */

        OPEN get_emp_id_c (ln_user_id);

        ln_emp_id   := NULL;

        FETCH get_emp_id_c INTO ln_emp_id;

        CLOSE get_emp_id_c;

        fnd_file.put_line (fnd_file.LOG, 'BF UPDATE');


        /*  BEGIN
          UPDATE po_requisitions_interface_all
               SET DELIVER_TO_REQUESTOR_ID = ln_emp_id, PREPARER_ID = ln_emp_id;
           EXCEPTION
            WHEN OTHERS THEN
               fnd_file.put_line (fnd_file.LOG, ' Exception occurred update1 ');
          END;
           BEGIN
            UPDATE po_requisitions_interface_all pria
               SET REQ_NUMBER_SEGMENT1 =
                      (SELECT NVL(PURCHASE_REQ_NUMBER,REQUISITION_NUMBER)
                         FROM XXD_PO_REQUISITION_CONV_STG_T XPRC,
                              oe_order_headers_all ooha,
                              oe_order_lines_all oola
                        WHERE     XPRC.REQUISITION_NUMBER =
                                     ooha.ORIG_SYS_DOCUMENT_REF
                              AND oola.LINE_ID = pria.INTERFACE_SOURCE_LINE_ID
                              AND XPRC.record_status = 'P'
                              AND oola.header_id = ooha.header_id
                              AND ROWNUM = 1),
                   CREATION_DATE =
                      NVL((SELECT XPRC.PR_CREATION_DATE
                         FROM XXD_PO_REQUISITION_CONV_STG_T XPRC,
                              oe_order_headers_all ooha,
                              oe_order_lines_all oola
                        WHERE     XPRC.REQUISITION_NUMBER =
                                     ooha.ORIG_SYS_DOCUMENT_REF
                              AND oola.LINE_ID = pria.INTERFACE_SOURCE_LINE_ID
                              AND XPRC.record_status = 'P'
                              AND oola.header_id = ooha.header_id
                              AND ROWNUM = 1) ,SYSDATE)          ;
          EXCEPTION
            WHEN OTHERS THEN
               fnd_file.put_line (fnd_file.LOG, ' Exception occurred update2 ');
          END;
              fnd_file.put_line (fnd_file.LOG, 'AF 1st UPDATE');
          BEGIN
            UPDATE po_requisitions_interface_all pria
               SET SUGGESTED_VENDOR_ID =
                      (SELECT vendor_id
                         FROM XXD_PO_REQUISITION_CONV_STG_T XPRC,
                              oe_order_headers_all ooha,
                              oe_order_lines_all oola
                        WHERE     XPRC.REQUISITION_NUMBER =
                                     ooha.ORIG_SYS_DOCUMENT_REF
                              AND oola.LINE_ID = pria.INTERFACE_SOURCE_LINE_ID
                              AND XPRC.record_status = 'P'
                              AND oola.header_id = ooha.header_id
                              AND ROWNUM = 1);
         EXCEPTION
            WHEN OTHERS THEN
               fnd_file.put_line (fnd_file.LOG, ' Exception occurred update3 ');
          END;
         BEGIN
            UPDATE po_requisitions_interface_all pria
               SET SUGGESTED_VENDOR_SITE_ID =
                      (SELECT vendor_site_id
                         FROM XXD_PO_REQUISITION_CONV_STG_T XPRC,
                              oe_order_headers_all ooha,
                              oe_order_lines_all oola
                        WHERE     XPRC.REQUISITION_NUMBER =
                                     ooha.ORIG_SYS_DOCUMENT_REF
                              AND oola.LINE_ID = pria.INTERFACE_SOURCE_LINE_ID
                              AND XPRC.record_status = 'P'
                              AND oola.header_id = ooha.header_id
                              AND ROWNUM = 1);
         EXCEPTION
            WHEN OTHERS THEN
               fnd_file.put_line (fnd_file.LOG, ' Exception occurred update4 ');
          END;
          BEGIN
            UPDATE po_requisitions_interface_all pria
               SET SUGGESTED_BUYER_ID =
                      (SELECT ppf.person_id
                         FROM XXD_PO_REQUISITION_CONV_STG_T XPRC,
                              per_all_people_f ppf,
                              oe_order_headers_all ooha,
                              oe_order_lines_all oola
                        WHERE     XPRC.REQUISITION_NUMBER =
                                     ooha.ORIG_SYS_DOCUMENT_REF
                              AND oola.LINE_ID = pria.INTERFACE_SOURCE_LINE_ID
                              AND ppf.full_name = XPRC.agent_name
                              AND XPRC.record_status = 'P'
                              AND SYSDATE BETWEEN NVL (EFFECTIVE_START_DATE,
                                                       SYSDATE)
                                              AND NVL (EFFECTIVE_END_DATE, SYSDATE)
                              AND oola.header_id = ooha.header_id
                              AND ROWNUM = 1);
             EXCEPTION
            WHEN OTHERS THEN
               fnd_file.put_line (fnd_file.LOG, ' Exception occurred update5 ');
          END;*/



        -----ADDED TO UPDATE ATTRIBUTE15 IN PURCHASE REQ----
        SELECT apps.XXD_ONT_DS_SO_REQ_BATCH_S.NEXTVAL
          INTO v_batch_id
          FROM DUAL;                                       ---added on 28thmay

        BEGIN
            FOR REC_cur_line IN cur_line
            LOOP
                v_count   := v_count + 1;

                -- fnd_file.put_line (fnd_file.LOG, REC_cur_line.LINE_ID);

                /* begin
                 select requisition_header_id into v_requisition_header_id
                 from po_requisition_headers_all
                 where segment1 = NVL (REC_cur_line.PURCHASE_REQ_NUMBER,
                                 REC_cur_line.REQUISITION_NUMBER);
                 exception
                 when no_data_found
                 then v_requisition_header_id := null;
                 end;*/

                UPDATE po_requisitions_interface_all pria
                   SET LINE_ATTRIBUTE15 = REC_cur_line.po_line_id, -- NVL (REC_cur_line.old_IR_REQ_LINE_ID,REC_cur_line.po_line_id),
                                                                   REQ_NUMBER_SEGMENT1 = NVL (REC_cur_line.PURCHASE_REQ_NUMBER, REC_cur_line.REQUISITION_NUMBER), SUGGESTED_VENDOR_SITE_ID = REC_cur_line.VENDOR_SITE_ID,
                       SUGGESTED_VENDOR_ID = REC_cur_line.VENDOR_ID, CREATION_DATE = NVL (REC_cur_line.PR_CREATION_DATE, SYSDATE), UNIT_PRICE = REC_cur_line.UNIT_PRICE, --Added on 12-MAY-2015
                       SUGGESTED_BUYER_ID = REC_cur_line.SUGGESTED_BUYER_ID, LINE_ATTRIBUTE14 = REC_cur_line.shipment_num, --- added on 19th may
                                                                                                                           line_attribute_category = 'REQ_CONVERSION',
                       request_id = NULL, process_flag = NULL, DELIVER_TO_REQUESTOR_ID = ln_emp_id,
                       PREPARER_ID = ln_emp_id, DESTINATION_SUBINVENTORY = UPPER (REC_cur_line.DESTINATION_SUBINVENTORY), NEED_BY_DATE = REC_cur_line.NEED_BY_DATE,
                       batch_id = v_batch_id
                 WHERE REC_cur_line.LINE_ID = pria.INTERFACE_SOURCE_LINE_ID;
            END LOOP;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   ' Exception occurred update7 ' || SQLERRM);
        END;

        SELECT COUNT (*)
          INTO v_line_count
          FROM po_requisitions_interface_all
         WHERE LINE_ATTRIBUTE15 IS NOT NULL AND batch_id = v_batch_id;

        IF v_count = v_line_count
        THEN
            CALL_REQUISITION_IMPORT (X_ERRBUF, x_retcode, v_batch_id);
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                'not all lines got updated' || v_line_count || ',' || v_count);
            fnd_file.put_line (fnd_file.LOG, 'BATCH ID : ' || v_batch_id);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               ' Exception occurred ' || SQLERRM);
            RAISE;
    END;

    PROCEDURE CALL_REQUISITION_IMPORT (P_ERRBUF OUT NOCOPY VARCHAR2, P_RETCODE OUT NOCOPY NUMBER, P_BATCH_ID IN NUMBER)
    IS
        CURSOR get_distinct_org_id_c IS
            SELECT DISTINCT org_id
              FROM po_requisitions_interface_all
             WHERE INTERFACE_SOURCE_CODE = 'CTO' AND BATCH_ID = P_BATCH_ID;


        -- ln_batch_no           NUMBER;

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

        fnd_file.put_line (fnd_file.LOG, ' IN  get_distinct_org_id_c cursor');

        LOOP
            ln_org_id   := NULL;

            FETCH get_distinct_org_id_c INTO ln_org_id;

            EXIT WHEN get_distinct_org_id_c%NOTFOUND;


            MO_GLOBAL.init ('PO');
            mo_global.set_policy_context ('S', ln_org_id);
            FND_REQUEST.SET_ORG_ID (ln_org_id);
            fnd_file.put_line (fnd_file.LOG,
                               'Org id ' || mo_global.get_current_org_id);



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
            fnd_file.put_line (fnd_file.LOG,
                               'ln_request_id' || ln_request_id);

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

        --fnd_file.put_line (fnd_file.LOG, 'Test4');

        fnd_file.put_line (fnd_file.LOG, 'Test4');
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
                    --     ELSE
                    --       RAISE request_submission_failed;
                    END IF;
                EXCEPTION
                    /*   WHEN request_submission_failed
                         THEN
                            print_log_prc (
                               p_debug,
                                  'Child Concurrent request submission failed - '
                               || ' XXD_AP_INV_CONV_VAL_WORK - '
                               || ln_request_id
                               || ' - '
                               || SQLERRM);
                         WHEN request_completion_abnormal
                         THEN
                            print_log_prc (
                               p_debug,
                                  'Submitted request completed with error'
                               || ' XXD_AP_INVOICE_CONV_VAL_WORK - '
                               || ln_request_id); */
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Code pointer ' || gc_code_pointer);

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Error message ' || SUBSTR (SQLERRM, 1, 240));
                END;
            END LOOP;
        ELSE
            fnd_file.put_line (fnd_file.LOG,
                               'no data inserted into req interface table');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               ' Exception REQ IMPORT occurred ' || SQLERRM);
            RAISE;
    END;

    PROCEDURE UPDATE_ORDER_ATTRIBUTE (p_scenario IN VARCHAR2)
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
                                  FROM XXD_PO_REQUISITION_CONV_STG_T XPRC
                                 WHERE     XPRC.REQUISITION_NUMBER =
                                           ooha.ORIG_SYS_DOCUMENT_REF
                                       AND XPRC.record_status = 'P' --AND SCENARIO = 'EUROPE'
                                       AND XPRC.scenario = p_scenario)
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

    PROCEDURE UPDATE_note_to_receiver (p_scenario IN VARCHAR2)
    IS
        CURSOR get_line_id_c IS
            SELECT plla.line_location_id, prla.note_to_receiver, xprc.need_by_date
              FROM mtl_reservations mr, oe_order_lines_all OLA, OE_ORDER_HEADERS_ALL OHA,
                   APPS.hr_operating_units hou, po_requisition_lines_all prla, po_line_locations_all plla,
                   po_lines_all pla, po_headers_all pha, xxd_conv.XXD_PO_REQUISITION_CONV_STG_T xprc
             WHERE     OHA.HEADER_ID = OLA.HEADER_ID
                   AND hou.organization_id = oha.org_id
                   AND mr.DEMAND_SOURCE_LINE_ID = ola.line_id
                   AND mr.ORIG_SUPPLY_SOURCE_LINE_ID =
                       prla.REQUISITION_LINE_ID
                   AND mr.SUPPLY_SOURCE_TYPE_ID = 1
                   AND hou.name = 'Deckers Macau OU'
                   AND prla.line_location_id = ola.attribute16
                   AND prla.note_to_agent LIKE '%' || oha.order_number || '%'
                   AND plla.line_location_id = prla.line_location_id
                   AND pla.po_line_id = plla.po_line_id
                   AND plla.po_header_id = pha.po_header_id
                   AND pha.org_id = oha.org_id
                   --AND pha.AUTHORIZATION_STATUS = 'APPROVED'
                   AND NVL (xprc.order_number, xprc.po_number) =
                       oha.order_number
                   AND xprc.po_number = pha.segment1
                   AND xprc.po_line_id = pla.attribute15
                   AND XPRC.record_status = 'P'
                   AND SCENARIO = p_scenario;

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
                    UPDATE po_line_locations_all
                       SET note_to_receiver = get_line_id_T (i).note_to_receiver
                     WHERE line_location_id =
                           get_line_id_T (i).line_location_id;


                FORALL i IN 1 .. get_line_id_T.COUNT SAVE EXCEPTIONS
                    UPDATE po_line_locations_all
                       SET need_by_date   = get_line_id_T (i).need_by_date
                     WHERE line_location_id =
                           get_line_id_T (i).line_location_id;
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

    PROCEDURE submit_po_request (p_org_id IN NUMBER, p_scenario IN VARCHAR2)
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
    IS
        ln_request_id              NUMBER := 0;
        ln_loop_counter            NUMBER := 1;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id                   request_table;
        lc_openpo_hdr_phase        VARCHAR2 (50);
        lc_openpo_hdr_status       VARCHAR2 (100);
        lc_openpo_hdr_dev_phase    VARCHAR2 (100);
        lc_openpo_hdr_dev_status   VARCHAR2 (100);
        lc_openpo_hdr_message      VARCHAR2 (3000);
        lc_submit_openpo           VARCHAR2 (10) := 'N';
        lb_openpo_hdr_req_wait     BOOLEAN;

        CURSOR get_distinct_batch_id_c                   --(p_batch_id NUMBER)
                                       IS
            SELECT DISTINCT batch_id
              FROM po_headers_interface phi, XXD_po_REQUISITION_CONV_STG_T XPO
             WHERE     phi.document_num = xpo.po_number
                   AND XPO.SCENARIO = P_SCENARIO;
    BEGIN
        --fnd_file.put_line (fnd_file.LOG, 'p_org_id ' || p_org_id);
        MO_GLOBAL.init ('PO');
        mo_global.set_policy_context ('S', p_org_id);
        FND_REQUEST.SET_ORG_ID (p_org_id);

        -- DBMS_APPLICATION_INFO.set_client_info (p_org_id);
        FOR i IN get_distinct_batch_id_c
        LOOP
            ln_request_id   :=
                fnd_request.submit_request (
                    application   => gc_appl_shrt_name,
                    program       => gc_program_shrt_name,
                    description   => NULL,
                    start_time    => NULL,
                    sub_request   => FALSE,
                    argument1     => NULL,
                    argument2     => gc_standard_type,
                    argument3     => NULL,
                    argument4     => gc_update_create,
                    argument5     => NULL,
                    argument6     => gc_approved,
                    argument7     => NULL,
                    argument8     => i.batch_id,
                    argument9     => p_org_id,
                    argument10    => NULL,
                    argument11    => NULL,
                    argument12    => NULL,
                    argument13    => NULL);

            IF ln_request_id > 0
            THEN
                COMMIT;
                l_req_id (ln_loop_counter)   := ln_request_id;
                ln_loop_counter              := ln_loop_counter + 1;
            /*  ELSE
                 ROLLBACK; */
            END IF;
        END LOOP;

        IF ln_request_id = 0
        THEN
            write_log ('Seeded Open PO import program POXPOPDOI failed ');
        ELSE
            FOR rec IN l_req_id.FIRST .. l_req_id.LAST
            LOOP
                BEGIN
                    IF l_req_id (rec) IS NOT NULL
                    THEN
                        -- wait for request to complete.
                        lc_openpo_hdr_dev_phase   := NULL;
                        lc_openpo_hdr_phase       := NULL;

                        LOOP
                            lb_openpo_hdr_req_wait   :=
                                FND_CONCURRENT.WAIT_FOR_REQUEST (
                                    request_id   => l_req_id (rec),
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

                                write_log (
                                       ' Open PO Import debug: request_id: '
                                    || ln_request_id
                                    || ', lc_openpo_hdr_dev_phase: '
                                    || lc_openpo_hdr_dev_phase
                                    || ',lc_openpo_hdr_phase: '
                                    || lc_openpo_hdr_phase);

                                EXIT;
                            END IF;
                        END LOOP;
                    END IF;
                EXCEPTION
                    /*    WHEN request_submission_failed
                        THEN
                           print_log_prc (
                              p_debug,
                                 'Child Concurrent request submission failed - '
                              || ' XXD_AP_INV_CONV_VAL_WORK - '
                              || ln_request_id
                              || ' - '
                              || SQLERRM);
                        WHEN request_completion_abnormal
                        THEN
                           print_log_prc (
                              p_debug,
                                 'Submitted request completed with error'
                              || ' XXD_AP_INVOICE_CONV_VAL_WORK - '
                              || ln_request_id); */
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error message durinf submit request '
                            || SUBSTR (SQLERRM, 0, 240));
                END;
            END LOOP;

            COMMIT;
        -- p_submit_openpo := lc_submit_openpo;
        END IF;
    END submit_po_request;

    -- To generate the proces report..

    PROCEDURE XXD_AUTOCREATE_PO_TRADE (  --p_batch_id                  NUMBER,
                                       P_ERRBUF OUT NOCOPY VARCHAR2, P_RETCODE OUT NOCOPY NUMBER --P_BUYER_ID                  NUMBER,
                                                                                                --P_OU                        NUMBER,
                                                                                                --P_PO_STATUS   IN            VARCHAR2
                                                                                                , p_scenario IN VARCHAR2)
    IS
        CURSOR Cur_PO_HEADERS_interface           --(P_PROFILE_VALUE VARCHAR2)
                                        IS
            SELECT DISTINCT
                   'STANDARD' type_lookup_code,
                   PRHA.org_id,
                   --PRLA.SUGGESTED_BUYER_ID agent_id,
                   APS.VENDOR_ID vendor_id,
                   APSS.VENDOR_SITE_ID vendor_site_id,
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
                       WHEN SOB.CURRENCY_CODE != PRLA.currency_code THEN -- PRLA.rate
                                                                         NULL
                       ELSE NULL
                   END rate,
                   NULL pcard_id,
                   --prla.deliver_to_location_id SHIP_TO_LOCATION_ID,
                   apss.bill_to_location_id,
                   hrou.location_id SHIP_TO_LOCATION_ID,
                   MCB.SEGMENT1 BRAND,
                   'PO Data Elements' ATTRIBUTE_CATEGORY,
                   NULL ATTRIBUTE9,
                   NULL ATTRIBUTE8,
                   NULL ATTRIBUTE11,
                   NULL ATTRIBUTE10,
                   /*TO_CHAR (
                      (  prla.need_by_date
                       - (CASE
                             WHEN MSB.ATTRIBUTE28 = 'SAMPLE'
                             THEN
                                NVL (
                                   (SELECT FLV.ATTRIBUTE5
                                      FROM FND_LOOKUP_VALUES FLV
                                     WHERE     FLV.LANGUAGE = 'US'
                                           AND FLV.LOOKUP_TYPE =
                                                  'XXDO_SUPPLIER_INTRANSIT'
                                           AND FLV.ATTRIBUTE1 = PRLA.VENDOR_ID
                                           AND FLV.ATTRIBUTE2 =
                                                  APSS.vendor_site_CODE
                                           -- AND FLV.ATTRIBUTE3 = mp.organization_code
                                           AND FLV.ATTRIBUTE4 =
                                                  mp.organization_id),
                                   0)                                      ---AIR
                             ELSE
                                NVL (
                                   (SELECT FLV.ATTRIBUTE6
                                      FROM FND_LOOKUP_VALUES FLV
                                     WHERE     FLV.LANGUAGE = 'US'
                                           AND FLV.LOOKUP_TYPE =
                                                  'XXDO_SUPPLIER_INTRANSIT'
                                           AND FLV.ATTRIBUTE1 = PRLA.VENDOR_ID
                                           AND FLV.ATTRIBUTE2 =
                                                  APSS.vendor_site_CODE
                                           -- AND FLV.ATTRIBUTE3 = mp.organization_code
                                           AND FLV.ATTRIBUTE4 =
                                                  mp.organization_id),
                                   0)                                     --ocean
                          END)),
                      'YYYY/MM/DD')
                      X_Factory_Date,*/
                   /* TO_CHAR (prla.REQUISITION_HEADER_ID)
                 || '-'
                 || prla.deliver_to_location_id*/
                   NVL (XPRC.PO_NUMBER, XPRC.requisition_number) PO_NUMBER,
                   --XPRC.requisition_number,
                   NVL (XPRC.PO_NUMBER, XPRC.requisition_number) group_code,
                   --  ppf.person_id agent_id,
                   XPRC.new_agent_id agent_id,
                   XPRC.po_header_id ATTRIBUTE15,
                   XPRC.PO_CREATION_DATE,
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
                   --XPRC.po_line_id
                   2   T
              FROM PO_REQUISITION_HEADERS_ALL prha, po_requisition_lines_all prla, po_req_distributions_all PRDA,
                   GL_SETS_OF_BOOKS SOB, MTL_CATEGORIES_B mcb, mtl_item_categories mic,
                   MTL_CATEGORY_SETS_VL MCS, AP_SUPPLIERS APS, ap_supplier_sites_all APSS,
                   mtl_parameters mp, FND_ID_FLEX_STRUCTURES ffs, mtl_system_items_b msb,
                   hr_organization_units HROU, --  APPS.oe_order_headers_all oha,
                                               -- APPS.oe_order_lines_all ola,
                                               XXD_PO_REQUISITION_CONV_STG_T XPRC --,per_all_people_f ppf
                                                                                 -- ,po_agents pa
                                                                                 , hr_operating_units hou
             WHERE     prha.AUTHORIZATION_STATUS = 'APPROVED'
                   AND PRHA.REQUISITION_HEADER_ID =
                       PRLA.REQUISITION_HEADER_ID
                   /*AND ppf.full_name = XPRC.agent_name
                   and pa.agent_id = ppf.person_id
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (nvl(ppf.effective_start_date,sysdate))
                                           AND TRUNC (nvl(ppf.effective_end_date,sysdate))
                                           AND TRUNC (SYSDATE) BETWEEN TRUNC (nvl(pa.start_date_active,sysdate))
                                           AND TRUNC (nvl(pa.end_date_active,sysdate))*/
                   --AND oha.ORIG_SYS_DOCUMENT_REF = XPRC.REQUISITION_NUMBER
                   AND XPRC.record_status = 'P'
                   AND xprc.po_line_id = prla.ATTRIBUTE15
                   AND NVL (XPRC.purchase_req_number,
                            XPRC.requisition_number) =
                       prha.segment1
                   -- AND NVL (xprc.line_attribute15, xprc.po_line_id) =
                   --      NVL (prla.ATTRIBUTE15, 'ABC')
                   -- and APS.vendor_id = xprc.vendor_id
                   -- and APSS.vendor_site_id = xprc.vendor_site_id
                   AND PRDA.REQUISITION_LINE_ID = PRLA.REQUISITION_LINE_ID
                   AND PRHA.org_id = hou.organization_id
                   AND hou.name = 'Deckers Macau OU'
                   AND PRDA.SET_OF_BOOKS_ID = SOB.SET_OF_BOOKS_ID
                   AND PRLA.item_id = mic.inventory_item_id
                   AND prla.destination_organization_id = mic.organization_id
                   AND prla.destination_organization_id =
                       HROU.organization_id
                   AND MCS.CATEGORY_SET_ID = MIC.CATEGORY_SET_ID
                   AND MCS.CATEGORY_SET_NAME = 'Inventory'
                   AND mic.category_id = mcb.category_id
                   AND mcb.structure_id = ffs.id_flex_num
                   AND ffs.ID_FLEX_STRUCTURE_CODE = 'ITEM_CATEGORIES'
                   --AND PRLA.VENDOR_ID = APS.VENDOR_ID
                   AND (APS.vendor_id = prla.vendor_id OR APS.vendor_name = prla.suggested_vendor_name)
                   AND APS.ENABLED_FLAG = 'Y'
                   AND (APSS.vendor_site_id = prla.vendor_site_id OR APSS.vendor_site_code = prla.suggested_vendor_location)
                   AND APSS.VENDOR_ID = APS.VENDOR_ID
                   AND APSS.ORG_ID = PRHA.org_id
                   AND (mp.ATTRIBUTE13 = 2 OR mp.ATTRIBUTE13 IS NULL)
                   AND prla.destination_organization_id = mp.organization_id
                   AND PRLA.item_id = msb.inventory_item_id
                   AND prla.destination_organization_id = msb.organization_id
                   AND prla.line_location_id IS NULL
                   AND (prla.cancel_flag = 'N' OR prla.cancel_flag IS NULL)
                   AND prha.interface_source_code = 'CTO'
                   AND XPRC.SCENARIO = P_SCENARIO           --ADDED ON 02 JUNE
                                                 --AND prha.segment1 = '58298' --Added for testing
                                                 --  AND ola.header_id = oha.header_id
                                                 -- AND prha.interface_source_line_id = ola.line_id --AND prha.segment1 = '500000052'
                                                 ;


        CURSOR Cur_PO_LINES_interface   --(          P_PROFILE_VALUE VARCHAR2)
                                      IS
            SELECT prla.item_id,
                   CASE
                       WHEN scenario = 'APAC' THEN xprc.po_unit_price
                       ELSE Prla.unit_price
                   END unit_price,
                   XPRC.po_line_num,                    --Added on 12-MAY-2015
                   xprc.shipment_num,                       --added on 19thmay
                   CASE
                       WHEN scenario = 'APAC' THEN xprc.pol_quantity
                       ELSE Prla.quantity
                   END quantity,
                   Prla.item_description,
                   prla.unit_meas_lookup_code,
                   prla.category_id,
                   prla.requisition_line_id,
                   prla.job_id,
                   xprc.need_by_date,
                   prla.line_type_id,
                   POHI.INTERFACE_HEADER_ID,
                   prla.deliver_to_location_id,
                   HROU.organization_id ship_to_organization_id,
                   POHI.SHIP_TO_LOCATION_ID,
                   prla.note_to_receiver,
                   'PO Line Locations Elements' shipment_attribute_CATEGORY,
                   /*  TO_CHAR (
                        (  TRUNC (prla.need_by_date)
                         - (CASE
                               WHEN MSB.ATTRIBUTE28 = 'SAMPLE'
                               THEN
                                  NVL (
                                     (SELECT FLV.ATTRIBUTE5
                                        FROM FND_LOOKUP_VALUES FLV
                                       WHERE     FLV.LANGUAGE = 'US'
                                             AND FLV.LOOKUP_TYPE =
                                                    'XXDO_SUPPLIER_INTRANSIT'
                                             AND FLV.ATTRIBUTE1 = PRLA.VENDOR_ID
                                             AND FLV.ATTRIBUTE2 =
                                                    APSS.vendor_site_CODE
                                             -- AND FLV.ATTRIBUTE3 = mp.organization_code
                                             AND FLV.ATTRIBUTE4 =
                                                    mp.organization_id),
                                     0)                                      ---AIR
                               ELSE
                                  NVL (
                                     (SELECT FLV.ATTRIBUTE6
                                        FROM FND_LOOKUP_VALUES FLV
                                       WHERE     FLV.LANGUAGE = 'US'
                                             AND FLV.LOOKUP_TYPE =
                                                    'XXDO_SUPPLIER_INTRANSIT'
                                             AND FLV.ATTRIBUTE1 = PRLA.VENDOR_ID
                                             AND FLV.ATTRIBUTE2 =
                                                    APSS.vendor_site_CODE
                                             -- AND FLV.ATTRIBUTE3 = mp.organization_code
                                             AND FLV.ATTRIBUTE4 =
                                                    mp.organization_id),
                                     0)                                     --ocean
                            END)),
                        'YYYY/MM/DD')
                        shipment_attribute4,
                     CASE
                        WHEN MSB.ATTRIBUTE28 = 'SAMPLE' THEN 'Air'
                        ELSE 'Ocean'
                     END
                        shipment_attribute10,*/
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
              FROM PO_REQUISITION_HEADERS_ALL prha, po_requisition_lines_all prla, po_req_distributions_all PRDA,
                   GL_SETS_OF_BOOKS SOB, MTL_CATEGORIES_B mcb, mtl_item_categories mic,
                   MTL_CATEGORY_SETS_VL MCS, AP_SUPPLIERS APS, ap_supplier_sites_all APSS,
                   PO_HEADERS_INTERFACE POHI, mtl_parameters mp, mtl_system_items_b msb,
                   --FND_LOOKUP_VALUES FLV,
                   FND_ID_FLEX_STRUCTURES ffs, hr_organization_units HROU, XXD_PO_REQUISITION_CONV_STG_T XPRC
             WHERE     prha.AUTHORIZATION_STATUS = 'APPROVED'
                   AND PRHA.REQUISITION_HEADER_ID =
                       PRLA.REQUISITION_HEADER_ID
                   AND PRDA.REQUISITION_LINE_ID = PRLA.REQUISITION_LINE_ID
                   AND PRHA.TYPE_LOOKUP_CODE = 'PURCHASE'
                   --AND PRHA.org_id = 86
                   --AND PRHA.org_id = HROU.organization_id
                   --AND HROU.name = 'Deckers Macau OU'
                   AND PRDA.SET_OF_BOOKS_ID = SOB.SET_OF_BOOKS_ID
                   --AND PRLA.SUGGESTED_BUYER_ID = NVL(P_BUYER_ID,PRLA.SUGGESTED_BUYER_ID)
                   -- AND PRLA.CATEGORY_ID = MCB.CATEGORY_ID
                   AND PRLA.item_id = mic.inventory_item_id
                   AND prla.destination_organization_id = mic.organization_id
                   AND prla.destination_organization_id =
                       HROU.organization_id
                   AND MCS.CATEGORY_SET_ID = MIC.CATEGORY_SET_ID
                   AND MCS.CATEGORY_SET_NAME = 'Inventory'
                   AND mic.category_id = mcb.category_id
                   -- AND MCB.attribute_category = 'PO Mapping Data Elements'
                   AND mcb.structure_id = ffs.id_flex_num
                   AND ffs.ID_FLEX_STRUCTURE_CODE = 'ITEM_CATEGORIES'
                   AND PRLA.VENDOR_ID = APS.VENDOR_ID
                   AND APS.ENABLED_FLAG = 'Y'
                   AND (APSS.vendor_site_id = prla.vendor_site_id OR APSS.vendor_site_code = prla.suggested_vendor_location)
                   AND APSS.VENDOR_ID = APS.VENDOR_ID
                   AND APSS.ORG_ID = PRHA.org_id
                   AND (mp.ATTRIBUTE13 = 2 OR mp.ATTRIBUTE13 IS NULL)
                   AND prla.destination_organization_id = mp.organization_id
                   AND PRLA.item_id = msb.inventory_item_id
                   AND prla.destination_organization_id = msb.organization_id
                   AND prla.line_location_id IS NULL
                   AND (prla.cancel_flag = 'N' OR prla.cancel_flag IS NULL)
                   AND POHI.VENDOR_ID = APS.VENDOR_ID
                   AND POHI.VENDOR_SITE_ID = APSS.vendor_site_id
                   AND POHI.AGENT_ID = PRLA.SUGGESTED_BUYER_ID
                   AND POHI.org_id = prha.org_id
                   AND NVL (XPRC.purchase_req_number,
                            XPRC.requisition_number) =
                       prha.segment1
                   -- AND pohi.ship_to_location_id = prla.deliver_to_location_id
                   --AND POHI.BATCH_ID = p_batch_id
                   AND pohi.currency_code =
                       NVL (prla.currency_code, sob.currency_code)
                   AND POHI.group_code =
                       NVL (XPRC.PO_NUMBER, XPRC.requisition_number)
                   --AND prha.segment1 = NVL(XPRC.PURCHASE_REQ_NUMBER,XPRC.REQUISITION_NUMBER)
                   AND TO_CHAR (xprc.po_line_id) = prla.ATTRIBUTE15
                   AND XPRC.SCENARIO = P_SCENARIO
                   --- and xprc.shipment_num = prla.attribute14
                   -- AND NVL (xprc.line_attribute15, xprc.po_line_id) =
                   --      NVL (prla.ATTRIBUTE15, 'ABC')
                   AND XPRC.record_status = 'P';

        CURSOR cur_update_edi IS
            SELECT DISTINCT pha.po_header_id, XPO.EDI_PROCESSED_FLAG, xpo.EDI_PROCESSED_STATUS
              FROM po_headers_all pha, hr_operating_units hou, XXD_po_REQUISITION_CONV_STG_T XPO
             WHERE     pha.org_id = hou.orgANIZATION_id
                   AND hou.name = 'Deckers Macau OU'
                   AND xpo.PO_NUMBER = pha.segment1
                   AND XPO.po_header_id = pha.attribute15--AND XPO.SCENARIO = P_SCENARIO
                                                         ;


        CURSOR cur_po_headers IS
            SELECT poh.segment1 po_num, prha.segment1 requisition_num, prla.line_num requisition_line_num
              FROM po_headers_all poh, po_headers_interface phi, po_requisition_headers_all prha,
                   po_requisition_lines_all prla, po_distributions_all pda, po_req_distributions_all prda
             WHERE     1 = 1
                   --AND phi.batch_id = p_batch_id
                   AND phi.po_header_id = poh.po_header_id
                   AND pda.po_header_id = poh.po_header_id
                   AND pda.req_distribution_id = prda.distribution_id
                   AND prda.requisition_line_id = prla.requisition_line_id
                   AND prla.requisition_header_id =
                       prha.requisition_header_id;

        CURSOR cur_po_errors IS
            SELECT DISTINCT error_message
              FROM (SELECT 'Requisition#: ' || prha.segment1 || '|Requisition line num:' || prla.line_num || '| error_message: ' || poie.error_message || '|Grouped invalid column name and value: ' || poie.column_name || poie.COLUMN_VALUE AS error_message
                      FROM po_interface_errors poie, po_headers_interface phi, po_lines_interface pli,
                           PO_REQUISITION_HEADERS_ALL PRHA, PO_REQUISITION_LINES_ALL PRlA
                     WHERE     1 = 1
                           --AND poie.batch_id = p_batch_id
                           AND poie.batch_id = phi.batch_id
                           AND phi.interface_header_id =
                               poie.interface_header_id
                           AND phi.interface_header_id =
                               pli.interface_header_id(+)
                           AND PLI.REQUISITION_LINE_ID =
                               PRLA.REQUISITION_LINE_ID
                           AND PRLA.REQUISITION_HEADER_ID =
                               PRHA.REQUISITION_HEADER_ID);

        cur_po_headers_rec           cur_po_headers%ROWTYPE;
        cur_po_errors_rec            VARCHAR2 (250);
        v_document_creation_method   po_headers_all.document_creation_method%TYPE;
        --V_batch_id                       NUMBER := P_BATCH_ID;
        V_document_id                NUMBER;
        V_INTERFACE_HEADER_ID        NUMBER;
        V_document_number            PO_HEADERS_ALL.SEGMENT1%TYPE;
        PO_HEADERS_interface_REC     Cur_PO_HEADERS_interface%ROWTYPE;
        PO_LINES_interface_REC       Cur_PO_LINES_interface%ROWTYPE;
        -- PO_DISTRIBUTIONS_interface_REC   Cur_PO_DISTRIBUTIONS_interface%ROWTYPE;
        -- cur_update_drop_ship_rec         cur_update_drop_ship%ROWTYPE;
        --INSERT_XXD_PO_COPY_REC           INSERT_XXD_PO_COPY_T%ROWTYPE;

        v_return_status              VARCHAR2 (50);
        v_dropship_Msg_Count         VARCHAR2 (50);
        v_dropship_Msg_data          VARCHAR2 (50);
        v_processed_lines_count      NUMBER := 0;
        v_rejected_lines_count       NUMBER := 0;
        --V_LINE_COUNT                 NUMBER := 0;
        v_err_tolerance_exceeded     VARCHAR2 (100);
        v_resp_appl_id               NUMBER;
        v_resp_id                    NUMBER;
        v_user_id                    NUMBER;
        v_dropship_return_status     VARCHAR2 (50);
        V_PROFILE_VALUE              VARCHAR2 (100);
        ln_request_id                NUMBER;
        v_po_line_id                 NUMBER;
        v_batch_id                   NUMBER;
        v_org_id                     NUMBER;
        v_count1                     NUMBER := 1;
        ln_cnt                       NUMBER := 0;
    BEGIN
        fnd_file.PUT_LINE (fnd_file.LOG, 'Start');

        v_resp_appl_id   := fnd_global.resp_appl_id;
        v_resp_id        := fnd_global.resp_id;
        v_user_id        := fnd_global.user_id;
        APPS.fnd_global.APPS_INITIALIZE (v_user_id,
                                         v_resp_id,
                                         v_resp_appl_id);
        --  APPS.fnd_global.APPS_INITIALIZE (0, 50766, 201);

        fnd_file.PUT_LINE (fnd_file.LOG, 'after apps initialize');

        /*         MO_GLOBAL.SET_POLICY_CONTEXT('S',81);
      DBMS_OUTPUT.PUT_LINE('after Policy context');*/

        mo_global.init ('PO');

        SELECT profile_option_name
          INTO V_PROFILE_VALUE
          FROM FND_PROFILE_OPTIONS_vl
         WHERE user_profile_option_name = 'MO: Security Profile';

        -- DELETE po_headers_interface;

        --DELETE po_lines_interface;

        --DELETE PO_DISTRIBUTIONS_INTERFACE;

        SELECT PO_CONTROL_GROUPS_S.NEXTVAL INTO v_batch_id FROM DUAL;

        OPEN Cur_PO_HEADERS_interface                      --(V_PROFILE_VALUE)
                                     ;

        LOOP
            FETCH Cur_PO_HEADERS_interface INTO PO_HEADERS_interface_REC;

            EXIT WHEN Cur_PO_HEADERS_interface%NOTFOUND;

            IF v_count1 = 50
            THEN
                v_count1   := 1;

                SELECT PO_CONTROL_GROUPS_S.NEXTVAL INTO v_batch_id FROM DUAL;
            END IF;

            fnd_file.PUT_LINE (fnd_file.LOG, 'after fetch');

            IF Cur_PO_HEADERS_interface%NOTFOUND
            THEN
                CLOSE Cur_PO_HEADERS_interface;

                RETURN;
            END IF;

            fnd_file.PUT_LINE (fnd_file.LOG, 'Before insert');

            INSERT INTO po_headers_interface (action, process_code, DOCUMENT_NUM, BATCH_ID, document_type_code, interface_header_id, created_by, document_subtype, agent_id, creation_date, vendor_id, vendor_site_id, currency_code, rate_type, rate_date, rate, pcard_id, group_code, ORG_ID, ship_to_location_id, bill_to_location_id, --attribute1,
                                                                                                                                                                                                                                                                                                                                          ATTRIBUTE_CATEGORY, ATTRIBUTE1, ATTRIBUTE2, ATTRIBUTE3, ATTRIBUTE4, ATTRIBUTE5, ATTRIBUTE6, ATTRIBUTE7, ATTRIBUTE8, ATTRIBUTE9, ATTRIBUTE10, ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14
                                              , ATTRIBUTE15)
                 VALUES ('ORIGINAL', NULL, PO_HEADERS_interface_REC.po_number, v_batch_id, 'STANDARD', po_headers_interface_s.NEXTVAL, fnd_profile.VALUE ('USER_ID'), PO_HEADERS_interface_REC.type_lookup_code, PO_HEADERS_interface_REC.agent_id, --SYSDATE,
                                                                                                                                                                                                                                                    PO_HEADERS_interface_REC.PO_CREATION_DATE, PO_HEADERS_interface_REC.vendor_id, PO_HEADERS_interface_REC.vendor_site_id, PO_HEADERS_interface_REC.currency_code, PO_HEADERS_interface_REC.rate_type, PO_HEADERS_interface_REC.rate_date, PO_HEADERS_interface_REC.rate, PO_HEADERS_interface_REC.pcard_id, PO_HEADERS_interface_REC.group_code, PO_HEADERS_interface_REC.ORG_ID, PO_HEADERS_interface_REC.ship_to_location_id, PO_HEADERS_interface_REC.bill_to_location_id, --PO_HEADERS_interface_REC.X_Factory_Date,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                --PO_HEADERS_interface_REC.HEADER_ATTRIBUTE_CATEGORY,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                PO_HEADERS_interface_REC.ATTRIBUTE_CATEGORY, PO_HEADERS_interface_REC.HEADER_ATTRIBUTE1, PO_HEADERS_interface_REC.HEADER_ATTRIBUTE2, PO_HEADERS_interface_REC.HEADER_ATTRIBUTE3, PO_HEADERS_interface_REC.HEADER_ATTRIBUTE4, PO_HEADERS_interface_REC.HEADER_ATTRIBUTE5, PO_HEADERS_interface_REC.HEADER_ATTRIBUTE6, PO_HEADERS_interface_REC.HEADER_ATTRIBUTE7, PO_HEADERS_interface_REC.HEADER_ATTRIBUTE8, PO_HEADERS_interface_REC.HEADER_ATTRIBUTE9, PO_HEADERS_interface_REC.HEADER_ATTRIBUTE10, PO_HEADERS_interface_REC.HEADER_ATTRIBUTE11, PO_HEADERS_interface_REC.HEADER_ATTRIBUTE12, PO_HEADERS_interface_REC.HEADER_ATTRIBUTE13, PO_HEADERS_interface_REC.HEADER_ATTRIBUTE14
                         , PO_HEADERS_interface_REC.ATTRIBUTE15);

            v_count1   := v_count1 + 1;
        END LOOP;

        CLOSE Cur_PO_HEADERS_interface;

        fnd_file.PUT_LINE (fnd_file.LOG, 'After headers');

        OPEN Cur_PO_LINES_interface;                      --(V_PROFILE_VALUE);

        LOOP
            FETCH Cur_PO_LINES_interface INTO PO_LINES_interface_REC;

            EXIT WHEN Cur_PO_LINES_interface%NOTFOUND;

            v_po_line_id   := NULL;

            ln_cnt         := ln_cnt + 1;

            BEGIN
                SELECT po_line_id
                  INTO v_po_line_id
                  FROM po_lines_interface
                 WHERE     line_attribute15 =
                           PO_LINES_interface_REC.LINE_attribute15
                       AND interface_header_id =
                           PO_LINES_interface_REC.interface_header_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    SELECT po_lines_s.NEXTVAL INTO v_po_line_id FROM DUAL;
            END;                                          --- added on 19thmay

            INSERT INTO po_lines_interface (action, interface_line_id, interface_header_id, unit_price, line_num, --Added on 12-MAY-2015
                                                                                                                  shipment_num, --added on 19thmay
                                                                                                                                po_line_id, ---added on 19thmay
                                                                                                                                            quantity, item_id, item_description, unit_OF_MEASURE, category_id, job_id, need_by_date, PROMISED_DATE, line_type_id, --                                         vendor_product_num,
                                                                                                                                                                                                                                                                  ip_category_id, requisition_line_id, ship_to_organization_id, SHIP_TO_LOCATION_ID, note_to_receiver, --shipment_attribute4,
                                                                                                                                                                                                                                                                                                                                                                       --shipment_attribute10,
                                                                                                                                                                                                                                                                                                                                                                       shipment_attribute_CATEGORY, LINE_ATTRIBUTE_CATEGORY_lines, LINE_ATTRIBUTE1, LINE_ATTRIBUTE2, LINE_ATTRIBUTE7, LINE_ATTRIBUTE14, LINE_ATTRIBUTE15, LINE_attribute3, LINE_attribute5, LINE_attribute6, LINE_attribute8, LINE_attribute9, LINE_attribute10, LINE_attribute11, LINE_attribute12, LINE_attribute13, --LINE_attribute14,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       --LINE_attribute15,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       SHIPMENT_attribute1, SHIPMENT_attribute2, SHIPMENT_attribute3, SHIPMENT_attribute4, SHIPMENT_attribute5, SHIPMENT_attribute6, SHIPMENT_attribute7, SHIPMENT_attribute8, SHIPMENT_attribute9, SHIPMENT_attribute10, SHIPMENT_attribute11, SHIPMENT_attribute12, SHIPMENT_attribute13, SHIPMENT_attribute14
                                            , SHIPMENT_attribute15)
                 VALUES ('ORIGINAL', po_lines_interface_s.NEXTVAL, PO_LINES_interface_REC.interface_header_id, PO_LINES_interface_REC.unit_price, PO_LINES_interface_REC.po_line_num, --Added on 12-MAY-2015
                                                                                                                                                                                      PO_LINES_interface_REC.shipment_num, --added on 19thmay
                                                                                                                                                                                                                           v_po_line_id, PO_LINES_interface_REC.quantity, PO_LINES_interface_REC.item_id, PO_LINES_interface_REC.item_description, PO_LINES_interface_REC.unit_meas_lookup_code, PO_LINES_interface_REC.category_id, PO_LINES_interface_REC.job_id, PO_LINES_interface_REC.need_by_date, PO_LINES_interface_REC.PROMISED_DATE, PO_LINES_interface_REC.line_type_id, --                      PO_LINES_interface_REC.vendor_product_num,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    NULL, PO_LINES_interface_REC.requisition_line_id, PO_LINES_interface_REC.ship_to_organization_id, PO_LINES_interface_REC.SHIP_TO_LOCATION_ID, PO_LINES_interface_REC.note_to_receiver, --PO_LINES_interface_REC.shipment_attribute4,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           --PO_LINES_interface_REC.shipment_attribute10,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           PO_LINES_interface_REC.shipment_attribute_CATEGORY, PO_LINES_interface_REC.LINE_ATTRIBUTE_CATEGORY, PO_LINES_interface_REC.LINE_ATTRIBUTE1, PO_LINES_interface_REC.LINE_ATTRIBUTE2, PO_LINES_interface_REC.LINE_ATTRIBUTE7, PO_LINES_interface_REC.LINE_ATTRIBUTE14, PO_LINES_interface_REC.LINE_ATTRIBUTE15, PO_LINES_interface_REC.LINE_attribute3, PO_LINES_interface_REC.LINE_attribute5, PO_LINES_interface_REC.LINE_attribute6, PO_LINES_interface_REC.LINE_attribute8, PO_LINES_interface_REC.LINE_attribute9, PO_LINES_interface_REC.LINE_attribute10, PO_LINES_interface_REC.LINE_attribute11, PO_LINES_interface_REC.LINE_attribute12, PO_LINES_interface_REC.LINE_attribute13, --PO_LINES_interface_REC.LINE_attribute14,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     --PO_LINES_interface_REC.LINE_attribute15,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     PO_LINES_interface_REC.SHIPMENT_attribute1, PO_LINES_interface_REC.SHIPMENT_attribute2, PO_LINES_interface_REC.SHIPMENT_attribute3, --Modified on 11-MAY-2015
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         TO_CHAR (TO_DATE (PO_LINES_interface_REC.SHIPMENT_ATTRIBUTE4, 'DD-MON-YY'), 'YYYY/MM/DD HH12:MI:SS'), TO_CHAR (TO_DATE (PO_LINES_interface_REC.SHIPMENT_attribute5, 'DD-MON-YY'), 'YYYY/MM/DD HH12:MI:SS'), --PO_LINES_interface_REC.SHIPMENT_attribute4,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     --PO_LINES_interface_REC.SHIPMENT_attribute5,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     --Modified on 11-MAY-2015
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     PO_LINES_interface_REC.SHIPMENT_attribute6, PO_LINES_interface_REC.SHIPMENT_attribute7, PO_LINES_interface_REC.SHIPMENT_attribute8, PO_LINES_interface_REC.SHIPMENT_attribute9, PO_LINES_interface_REC.SHIPMENT_attribute10, PO_LINES_interface_REC.SHIPMENT_attribute11, PO_LINES_interface_REC.SHIPMENT_attribute12, PO_LINES_interface_REC.SHIPMENT_attribute13, PO_LINES_interface_REC.SHIPMENT_attribute14
                         , PO_LINES_interface_REC.SHIPMENT_attribute15);
        --Added on 11-MAY-2015
        /* INSERT INTO PO_DISTRIBUTIONS_INTERFACE (INTERFACE_HEADER_ID,
                                                 INTERFACE_LINE_ID,
                                                 INTERFACE_DISTRIBUTION_ID,
                                                 --PO_HEADER_ID,
                                                 DISTRIBUTION_NUM,
                                                 ORG_ID,
                                                 DESTINATION_SUBINVENTORY,
                                                 QUANTITY_ORDERED--QUANTITY_DELIVERED,
                                                                 --QUANTITY_BILLED,
                                                                 --QUANTITY_CANCELLED
                                                 )
              VALUES (
                        PO_LINES_interface_REC.interface_header_id,
                        po_lines_interface_s.CURRVAL,
                        PO_DISTRIBUTIONS_INTERFACE_S.NEXTVAL,
                        --PO_HEADERS_S.CURRVAL,
                        ln_cnt,       --lcu_c_get_valid_rec1.DISTRIBUTION_NUM,
                        PO_HEADERS_interface_REC.ORG_ID,
                        NVL2 (
                           PO_LINES_interface_REC.DESTINATION_SUBINVENTORY,
                           'FACTORY',
                           PO_LINES_interface_REC.DESTINATION_SUBINVENTORY),
                        PO_LINES_interface_REC.DIST_QUANTITY--lcu_c_get_valid_rec1.QUANTITY_ORDERED,
                                                            --lcu_c_get_valid_rec1.QUANTITY_DELIVERED,
                                                            --lcu_c_get_valid_rec1.QUANTITY_BILLED,
                                                            --lcu_c_get_valid_rec1.QUANTITY_CANCELLED
                        );*/



        END LOOP;

        CLOSE Cur_PO_LINES_interface;

        fnd_file.PUT_LINE (fnd_file.LOG, 'After lines');
        fnd_file.PUT_LINE (fnd_file.output,
                           'last Batch ID is: ' || v_batch_id);

        /*OPEN Cur_PO_DISTRIBUTIONS_interface;

        LOOP
           FETCH Cur_PO_DISTRIBUTIONS_interface
           INTO PO_DISTRIBUTIONS_interface_REC;

           EXIT WHEN Cur_PO_DISTRIBUTIONS_interface%NOTFOUND;

           INSERT INTO po_distributions_interface (INTERFACE_HEADER_ID,
                                                   INTERFACE_LINE_ID,
                                                   INTERFACE_DISTRIBUTION_ID,
                                                   req_distribution_id,
                                                   deliver_to_location_id,
                                                   deliver_to_person_id,
                                                   rate_date,
                                                   rate,
                                                   destination_type_code,
                                                   destination_organization_id,
                                                   destination_subinventory,
                                                   budget_account_id,
                                                   accrual_account_id,
                                                   variance_account_id,
                                                   wip_entity_id,
                                                   wip_line_id,
                                                   wip_repetitive_schedule_id,
                                                   wip_operation_seq_num,
                                                   wip_resource_seq_num,
                                                   bom_resource_id,
                                                   project_id,
                                                   task_id,
                                                   expenditure_type,
                                                   destination_context,
                                                   tax_recovery_override_flag,
                                                   recovery_rate,
                                                   req_header_reference_num,
                                                   req_line_reference_num,
                                                   CHARGE_ACCOUNT_ID)
                VALUES (
                          PO_DISTRIBUTIONS_interface_REC.INTERFACE_HEADER_ID, ---    INTERFACE_HEADER_ID,
                          PO_DISTRIBUTIONS_interface_REC.INTERFACE_LINE_ID, --- INTERFACE_LINE_ID,
                          po_distributions_interface_s.NEXTVAL, --- INTERFACE_DISTRIBUTION_ID,
                          PO_DISTRIBUTIONS_interface_REC.req_distribution_id,
                          PO_DISTRIBUTIONS_interface_REC.deliver_to_location_id,
                          PO_DISTRIBUTIONS_interface_REC.deliver_to_person_id,
                          PO_DISTRIBUTIONS_interface_REC.rate_date,
                          PO_DISTRIBUTIONS_interface_REC.rate,
                          PO_DISTRIBUTIONS_interface_REC.destination_type_code,
                          PO_DISTRIBUTIONS_interface_REC.destination_organization_id,
                          PO_DISTRIBUTIONS_interface_REC.destination_subinventory,
                          PO_DISTRIBUTIONS_interface_REC.budget_account_id,
                          PO_DISTRIBUTIONS_interface_REC.accrual_account_id,
                          PO_DISTRIBUTIONS_interface_REC.variance_account_id,
                          PO_DISTRIBUTIONS_interface_REC.wip_entity_id,
                          PO_DISTRIBUTIONS_interface_REC.wip_line_id,
                          PO_DISTRIBUTIONS_interface_REC.wip_repetitive_schedule_id,
                          PO_DISTRIBUTIONS_interface_REC.wip_operation_seq_num,
                          PO_DISTRIBUTIONS_interface_REC.wip_resource_seq_num,
                          PO_DISTRIBUTIONS_interface_REC.bom_resource_id,
                          PO_DISTRIBUTIONS_interface_REC.project_id,
                          PO_DISTRIBUTIONS_interface_REC.task_id,
                          PO_DISTRIBUTIONS_interface_REC.expenditure_type,
                          PO_DISTRIBUTIONS_interface_REC.destination_context,
                          PO_DISTRIBUTIONS_interface_REC.tax_recovery_override_flag,
                          PO_DISTRIBUTIONS_interface_REC.recovery_rate,
                          PO_DISTRIBUTIONS_interface_REC.req_header_reference_num,
                          PO_DISTRIBUTIONS_interface_REC.req_line_reference_num,
                          PO_DISTRIBUTIONS_interface_REC.code_combination_id);
        END LOOP;

        CLOSE Cur_PO_DISTRIBUTIONS_interface; */



        /*     ln_request_id:=FND_REQUEST.SUBMIT_REQUEST
       ( application => 'PO'
       , program => 'POXPOPDOI'
       , description => 'Import Standard Purchase Orders'
       , start_time => null
       , sub_request => FALSE
       , argument1 => null
       , argument2 => 'STANDARD'
       , argument3 => null
       , argument4 => 'N'
       , argument5 => null
       , argument6 => 'APPROVED'
       , argument7 => null
       , argument8 => null
       , argument9 => null
       , argument10 => null);
       if ln_request_id =0
       then
       fnd_file.put_line(fnd_file.log,'Request Not Submitted');
       end if;  */
        BEGIN
            SELECT DISTINCT org_id
              INTO v_org_id
              FROM po_headers_interface
             WHERE batch_id = v_batch_id;

            submit_po_request (v_org_id, p_scenario);

            UPDATE_ORDER_ATTRIBUTE (p_scenario);

            UPDATE_note_to_receiver (p_scenario);

            BEGIN
                FOR i IN CUR_UPDATE_EDI
                LOOP
                    UPDATE po_headers_all
                       SET EDI_PROCESSED_FLAG = i.EDI_PROCESSED_FLAG, EDI_PROCESSED_STATUS = i.EDI_PROCESSED_STATUS
                     WHERE po_header_id = i.po_header_id;
                END LOOP;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_log ('others while updating edi flag' || SQLERRM);
            END;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                write_log ('batch_id is null');
        END;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            fnd_file.PUT_LINE (fnd_file.LOG, 'No Trade Requisition selected');
        WHEN OTHERS
        THEN
            fnd_file.PUT_LINE (fnd_file.LOG,
                               'CREATE CODE IN ERROR' || SQLCODE || SQLERRM);
            --DBMS_OUTPUT.PUT_LINE ('CREATE CODE IN ERROR' || SQLCODE || SQLERRM);
            ROLLBACK;
            P_RETCODE   := 2;
    END;



    PROCEDURE XXD_ORDER_IMPORT (P_ERRBUF OUT NOCOPY VARCHAR2, P_RETCODE OUT NOCOPY NUMBER, p_scenario IN VARCHAR2)
    IS
        CURSOR get_distinct_org_id_c IS
            SELECT DISTINCT prha.org_id
              FROM XXD_PO_REQUISITION_CONV_STG_T XPRC, PO_REQUISITION_HEADERS_ALL PRHA
             WHERE     1 = 1
                   --AND SCENARIO = 'REGULAR'
                   AND record_status = 'P'
                   AND PRHA.segment1 = XPRC.requisition_number
                   AND XPRC.NEW_ORG_ID = prha.org_id
                   AND XPRC.SCENARIO = P_SCENARIO;           --ADDED ON 02 JUN



        CURSOR Get_order_num_c IS
            SELECT DISTINCT requisition_number, PRHA.REQUISITION_HEADER_ID, xprc.ORDER_NUMBER,
                            XPRC.ISO_CREATION_DATE
              FROM XXD_PO_REQUISITION_CONV_STG_T XPRC, PO_REQUISITION_HEADERS_ALL PRHA, OE_HEADERS_IFACE_ALL OHIA
             WHERE     1 = 1
                   AND RECORD_STATUS = 'P'
                   AND OHIA.ORIG_SYS_DOCUMENT_REF =
                       TO_CHAR (PRHA.REQUISITION_HEADER_ID)
                   AND PRHA.segment1 = XPRC.requisition_number
                   AND XPRC.NEW_ORG_ID = prha.org_id
                   AND XPRC.SCENARIO = P_SCENARIO;           --ADDED ON 02 JUN


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

        ln_counter            NUMBER;

        ln_loop_counter       NUMBER := 1;
    BEGIN
        --Submitting Create Internal Orders

        fnd_file.put_line (fnd_file.LOG, 'Test1');

        OPEN get_distinct_org_id_c;

        LOOP
            ln_org_id   := NULL;

            FETCH get_distinct_org_id_c INTO ln_org_id;

            EXIT WHEN get_distinct_org_id_c%NOTFOUND;


            --fnd_global.APPS_INITIALIZE (0, 50721, 201);

            --fnd_file.put_line (fnd_file.LOG, 'Org id ' || ln_org_id);
            fnd_file.put_line (fnd_file.LOG, 'Test2');

            --fnd_global.APPS_INITIALIZE (l_user_id, l_resp_id, l_appl_id);
            MO_GLOBAL.init ('PO');
            mo_global.set_policy_context ('S', ln_org_id);
            FND_REQUEST.SET_ORG_ID (ln_org_id);
            DBMS_APPLICATION_INFO.set_client_info (ln_org_id);

            fnd_file.put_line (fnd_file.LOG,
                               'Org id ' || mo_global.get_current_org_id);

            ln_request_id   :=
                fnd_request.submit_request (
                    application   => 'PO',
                    PROGRAM       => 'POCISO',
                    description   => 'Create Internal Orders',
                    start_time    => SYSDATE,
                    sub_request   => FALSE);

            fnd_file.put_line (fnd_file.LOG, 'Test3');

            IF ln_request_id > 0
            THEN
                COMMIT;
                l_req_id (ln_loop_counter)   := ln_request_id;
                ln_loop_counter              := ln_loop_counter + 1;
            /*  ELSE
                 ROLLBACK; */
            END IF;
        END LOOP;

        CLOSE get_distinct_org_id_c;

        --fnd_file.put_line (fnd_file.LOG, 'Test4');
        fnd_file.put_line (fnd_file.LOG, 'Test4');

        gc_code_pointer   :=
            'Waiting for child requests in Create internal process  ';

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
                    /*ELSE
                       RAISE request_submission_failed; */
                    END IF;
                EXCEPTION
                    /*    WHEN request_submission_failed
                        THEN
                           print_log_prc (
                              p_debug,
                                 'Child Concurrent request submission failed - '
                              || ' XXD_AP_INV_CONV_VAL_WORK - '
                              || ln_request_id
                              || ' - '
                              || SQLERRM);
                        WHEN request_completion_abnormal
                        THEN
                           print_log_prc (
                              p_debug,
                                 'Submitted request completed with error'
                              || ' XXD_AP_INVOICE_CONV_VAL_WORK - '
                              || ln_request_id); */
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Code pointer ' || gc_code_pointer);

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Error message ' || SUBSTR (SQLERRM, 1, 240));
                END;
            END LOOP;
        ELSE
            fnd_file.put_line (fnd_file.LOG,
                               'no data inserted into req interface table');
        END IF;

        fnd_file.put_line (fnd_file.LOG, 'Test5');


        OPEN Get_order_num_c;

        LOOP
            FETCH Get_order_num_c INTO lcu_Get_order_num_c;

            EXIT WHEN Get_order_num_c%NOTFOUND;

            IF lcu_Get_order_num_c.ORDER_NUMBER IS NULL
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'requisition_number ' || lcu_Get_order_num_c.requisition_number);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'REQUISITION_HEADER_ID ' || lcu_Get_order_num_c.REQUISITION_HEADER_ID);

                UPDATE OE_HEADERS_IFACE_ALL
                   SET order_number = lcu_Get_order_num_c.requisition_number, booked_flag = 'Y'
                 WHERE ORIG_SYS_DOCUMENT_REF =
                       TO_CHAR (lcu_Get_order_num_c.REQUISITION_HEADER_ID);
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                    'order_number ' || lcu_Get_order_num_c.order_number);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'REQUISITION_HEADER_ID ' || lcu_Get_order_num_c.REQUISITION_HEADER_ID);

                UPDATE OE_HEADERS_IFACE_ALL
                   SET order_number = lcu_Get_order_num_c.order_number, booked_flag = 'Y'
                 WHERE ORIG_SYS_DOCUMENT_REF =
                       TO_CHAR (lcu_Get_order_num_c.REQUISITION_HEADER_ID);
            END IF;

            fnd_file.put_line (
                fnd_file.LOG,
                'ISO_CREATION_DATE ' || lcu_Get_order_num_c.ISO_CREATION_DATE);

            IF lcu_Get_order_num_c.ISO_CREATION_DATE IS NOT NULL
            THEN
                UPDATE OE_HEADERS_IFACE_ALL
                   SET CREATION_DATE = lcu_Get_order_num_c.ISO_CREATION_DATE
                 WHERE ORIG_SYS_DOCUMENT_REF =
                       TO_CHAR (lcu_Get_order_num_c.REQUISITION_HEADER_ID);
            END IF;
        END LOOP;

        COMMIT;

        CLOSE Get_order_num_c;

        /*    UPDATE OE_HEADERS_IFACE_ALL OHIA
               SET ORDER_NUMBER =
                      (SELECT requisition_number
                         FROM XXD_PO_REQUISITION_CONV_STG_T XPRC
                        WHERE     XPRC.NEW_ORG_ID = OHIA.org_id
                              AND XPRC.requisition_number =
                                     OHIA.ORIG_SYS_DOCUMENT_REF
                              AND RECORD_STATUS = 'P'
                              --AND SCENARIO = 'REGULAR'
                  );

            COMMIT; */

        --Order Import
        fnd_file.put_line (fnd_file.LOG, 'Test6');

        --Submitting Order Import

        CALL_ORDER_IMPORT (P_ERRBUF, P_RETCODE, p_scenario);
    END;

    PROCEDURE CALL_ORDER_IMPORT (P_ERRBUF OUT NOCOPY VARCHAR2, P_RETCODE OUT NOCOPY NUMBER, p_scenario IN VARCHAR2)
    IS
        CURSOR get_distinct_org_id_c1 IS
            SELECT DISTINCT OHIA.org_id
              FROM XXD_PO_REQUISITION_CONV_STG_T XPRC, PO_REQUISITION_HEADERS_ALL PRHA, OE_HEADERS_IFACE_ALL OHIA
             WHERE     1 = 1
                   --AND SCENARIO = 'REGULAR'
                   --AND record_status = 'P'
                   AND PRHA.segment1 = XPRC.requisition_number
                   AND OHIA.ORIG_SYS_DOCUMENT_REF =
                       TO_CHAR (PRHA.REQUISITION_HEADER_ID)
                   --AND OHIA.org_id = prha.org_id
                   AND XPRC.NEW_ORG_ID = prha.org_id
                   AND XPRC.SCENARIO = P_SCENARIO;           --ADDED ON 02 JUN

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
    BEGIN
        OPEN get_distinct_org_id_c1;

        LOOP
            ln_org_id   := NULL;

            fnd_file.put_line (fnd_file.LOG, 'Test7');

            FETCH get_distinct_org_id_c1 INTO ln_org_id;

            EXIT WHEN get_distinct_org_id_c1%NOTFOUND;

            fnd_file.put_line (fnd_file.LOG, 'Test8');

            --fnd_global.APPS_INITIALIZE (0, 50721, 201);

            --fnd_file.put_line (fnd_file.LOG, 'Org id ' || ln_org_id);


            --fnd_global.APPS_INITIALIZE (l_user_id, l_resp_id, l_appl_id);
            mo_global.init ('ONT');
            mo_global.set_policy_context ('S', ln_org_id);
            FND_REQUEST.SET_ORG_ID (ln_org_id);
            --DBMS_APPLICATION_INFO.set_client_info (ln_org_id);

            fnd_file.put_line (fnd_file.LOG,
                               'Org id1 ' || mo_global.get_current_org_id);

            ln_request_id   :=
                FND_REQUEST.SUBMIT_REQUEST (application   => 'ONT',
                                            program       => 'OEOIMP',
                                            description   => 'Order Import',
                                            start_time    => SYSDATE,
                                            sub_request   => NULL,
                                            argument1     => NULL,
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
                                            argument14    => NULL,
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
                    --ELSE
                    ---      RAISE request_submission_failed;
                    END IF;
                EXCEPTION
                    /*    WHEN request_submission_failed
                        THEN
                           print_log_prc (
                              p_debug,
                                 'Child Concurrent request submission failed - '
                              || ' XXD_AP_INV_CONV_VAL_WORK - '
                              || ln_request_id
                              || ' - '
                              || SQLERRM);
                        WHEN request_completion_abnormal
                        THEN
                           print_log_prc (
                              p_debug,
                                 'Submitted request completed with error'
                              || ' XXD_AP_INVOICE_CONV_VAL_WORK - '
                              || ln_request_id); */


                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Code pointer ' || gc_code_pointer);

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Error message ' || SUBSTR (SQLERRM, 1, 240));
                END;
            END LOOP;
        ELSE
            fnd_file.put_line (fnd_file.LOG,
                               'no data inserted into order interface table');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'ERROR WHILE ORDER IMPORT' || SQLERRM);
    END;
END XXD_PO_REQUISITION_CONV_PKG;
/
