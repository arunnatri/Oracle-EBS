--
-- XXD_INV_ITEM_ONHAND_QTY_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:37 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_INV_ITEM_ONHAND_QTY_PKG"
AS
    /*******************************************************************************
      * Program Name : XXD_INV_ITEM_ONHAND_QTY_PKG
      * Language     : PL/SQL
      * Description  : This package will load data in to party, Customer, location, site, uses, contacts, account.
      *
      * History      :
      *
      * WHO                  WHAT              Desc                             WHEN
      * -------------- ---------------------------------------------- ---------------
      * BT Technology Team    1.0                                              17-JUN-2014
      *******************************************************************************/

    TYPE XXD_INV_ONHAND_QTY_TAB
        IS TABLE OF XXD_INV_ITEM_ONHAND_QTY_STG_T%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_inv_onhand_qty_tab   XXD_INV_ONHAND_QTY_TAB;

    /******************************************************
            * Procedure: log_recordss
            *
            * Synopsis: This procedure will call we be called by the concurrent program
             * Design:
             *
             * Notes:
             *
             * PARAMETERS:
             *   IN    : p_debug    Varchar2
             *   IN    : p_message  Varchar2
             *
             * Return Values:
             * Modifications:
             *
             ******************************************************/


    PROCEDURE log_records (p_debug VARCHAR2, p_message VARCHAR2)
    IS
    BEGIN
        DBMS_OUTPUT.put_line (p_message);

        IF p_debug = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, p_message);
        END IF;
    END log_records;

    PROCEDURE get_org_id (p_org_name_id   IN     NUMBER,
                          x_org_name         OUT VARCHAR2,
                          x_org_id           OUT NUMBER)
    -- +===================================================================+
    -- | Name  : GET_ORG_ID                                                |
    -- | Description      : This procedure  is used to get                 |
    -- |                    org id from EBS                                |
    -- |                                                                   |
    -- | Parameters : p_org_name,p_request_id,p_inter_head_id              |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_org_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        px_lookup_code   VARCHAR2 (250);
        px_meaning       VARCHAR2 (250);        -- internal name of old entity
        px_description   VARCHAR2 (250);             -- name of the old entity
        x_attribute1     VARCHAR2 (250);     -- corresponding new 12.2.3 value
        x_attribute2     VARCHAR2 (250);
        x_error_code     VARCHAR2 (250);
        x_error_msg      VARCHAR (250);
    --          x_org_id                   NUMBER;
    BEGIN
        px_lookup_code   := p_org_name_id;
        apps.XXD_COMMON_UTILS.get_mapping_value (
            p_lookup_type    => 'XXD_1206_OU_MAPPING', -- Lookup type for mapping
            px_lookup_code   => px_lookup_code,
            -- Would generally be id of 12.0.6. eg: org_id
            px_meaning       => px_meaning,     -- internal name of old entity
            px_description   => px_description,      -- name of the old entity
            x_attribute1     => x_attribute1, -- corresponding new 12.2.3 value
            x_attribute2     => x_attribute2,
            x_error_code     => x_error_code,
            x_error_msg      => x_error_msg);

        SELECT organization_id
          INTO x_org_id
          FROM hr_operating_units
         WHERE UPPER (NAME) = UPPER (x_attribute1);

        x_org_name       := x_attribute1;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'INV',
                gn_org_id,
                'Decker Inventory Item Onhand Conversion Program',
                --      SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'GET_ORG_ID',
                p_org_name_id,
                'Exception to GET_ORG_ID Procedure' || SQLERRM);
            --       write_log( 'Exception to GET_ORG_ID Procedure' || SQLERRM);
            x_org_name   := NULL;
            x_org_id     := NULL;
    END get_org_id;


    PROCEDURE get_inv_org_id (p_inv_org_name_id IN NUMBER, x_inv_org_name OUT VARCHAR2, x_inv_org_id OUT NUMBER)
    -- +===================================================================+
    -- | Name  : GET_ORG_ID                                                |
    -- | Description      : This procedure  is used to get                 |
    -- |                    org id from EBS                                |
    -- |                                                                   |
    -- | Parameters : p_org_name,p_request_id,p_inter_head_id              |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_org_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        px_lookup_code   VARCHAR2 (250);
        px_meaning       VARCHAR2 (250);        -- internal name of old entity
        px_description   VARCHAR2 (250);             -- name of the old entity
        x_attribute1     VARCHAR2 (250);     -- corresponding new 12.2.3 value
        x_attribute2     VARCHAR2 (250);
        x_error_code     VARCHAR2 (250);
        x_error_msg      VARCHAR (250);
    --          x_org_id                   NUMBER;
    BEGIN
        px_lookup_code   := p_inv_org_name_id;
        apps.XXD_COMMON_UTILS.get_mapping_value (
            p_lookup_type    => 'XXD_1206_INV_ORG_MAPPING', -- Lookup type for mapping
            px_lookup_code   => px_lookup_code,
            -- Would generally be id of 12.0.6. eg: org_id
            px_meaning       => px_meaning,     -- internal name of old entity
            px_description   => px_description,      -- name of the old entity
            x_attribute1     => x_attribute1, -- corresponding new 12.2.3 value
            x_attribute2     => x_attribute2,
            x_error_code     => x_error_code,
            x_error_msg      => x_error_msg);

        SELECT organization_id
          INTO x_inv_org_id
          FROM org_organization_definitions
         WHERE UPPER (organization_code) = UPPER (x_attribute1);

        x_inv_org_name   := x_attribute1;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'INV',
                gn_org_id,
                'Decker Inventory Item Onhand Conversion Program',
                --      SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'get_inv_org_id',
                p_inv_org_name_id,
                'Exception to GET_INV_ORG_ID Procedure' || SQLERRM);
            --       write_log( 'Exception to GET_ORG_ID Procedure' || SQLERRM);
            x_inv_org_name   := NULL;
            x_inv_org_id     := NULL;
    END get_inv_org_id;



    FUNCTION get_po_status (p_po_header_id      IN NUMBER,
                            p_organization_id   IN NUMBER)
        RETURN NUMBER
    AS
        ln_cnt   NUMBER := 0;
    BEGIN
        SELECT COUNT (*)
          INTO ln_cnt
          FROM po_headers_all
         WHERE po_header_id = p_po_header_id AND org_id = p_organization_id;

        RETURN ln_cnt;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN ln_cnt;
        WHEN OTHERS
        THEN
            RETURN ln_cnt;
    END get_po_status;

    PROCEDURE extract_1206_data (x_total_rec           OUT NUMBER,
                                 x_errbuf              OUT VARCHAR2,
                                 x_retcode             OUT NUMBER,
                                 P_OPERATING_UNIT   IN     VARCHAR2,
                                 P_INVENTORY_ORG    IN     VARCHAR2)
    -- +=======================================================================+
    -- | Name  : extract_1206_data                                             |
    -- | Description      : This procedure  is used to extract                 |
    -- |                    data from 1206 dump table                          |
    -- |                                                                       |
    -- | Parameters : P_OPERATING_UNIT,P_INVENTORY_ORG                         |
    -- |                                                                       |
    -- |                                                                       |
    -- | Returns : x_org_id                                                    |
    -- |                                                                       |
    -- +=======================================================================+

    IS
        procedure_name   CONSTANT VARCHAR2 (30) := 'EXTRACT_R12';
        lv_error_stage            VARCHAR2 (50) := NULL;
        ln_record_count           NUMBER := 0;
        lv_string                 LONG;
        V_INVENTORY_ORG           NUMBER;
        V_OPERATING_UNIT          NUMBER;


        CURSOR lcu_ou IS
            SELECT lookup_code org_id
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_1206_OU_MAPPING'
                   AND attribute1 = NVL (P_OPERATING_UNIT, attribute1)
                   AND language = USERENV ('LANG');


        CURSOR lcu_1206_org IS
              SELECT DISTINCT mp.organization_code, mp.organization_id, ood.operating_unit,
                              hou.name
                FROM org_organization_definitions ood, mtl_parameters mp, fnd_lookup_values fl,
                     apps.hr_operating_units hou
               WHERE     ood.organization_id = mp.organization_id
                     AND fl.lookup_type = 'XXD_1206_INV_ORG_MAPPING'
                     AND fl.attribute1(+) = mp.organization_code
                     AND ood.operating_unit = hou.organization_id
                     AND hou.name = P_OPERATING_UNIT
                     AND mp.organization_code =
                         NVL (P_INVENTORY_ORG, mp.organization_code)
            ORDER BY mp.organization_code;

        CURSOR lcu_inv_org (P_INV_ORG VARCHAR2)
        IS
            SELECT TO_NUMBER (lookup_code) inventory_org_id, meaning Inventory_org_1206
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_1206_INV_ORG_MAPPING'
                   AND attribute1 = NVL (P_INV_ORG, attribute1)
                   AND language = USERENV ('LANG');

        CURSOR lcu_extract_count IS
            SELECT COUNT (*)
              FROM XXD_INV_ITEM_ONHAND_QTY_STG_T
             WHERE record_status = gc_new_status;

        --AND    source_org    = p_source_org_id;


        CURSOR lcu_onhand_qty_data IS
            SELECT /*+ FIRST_ROWS(10) */
                   'NEW' RECORD_STATUS, XXD_INV_ITEM_ONHAND_REC_SEQ.NEXTVAL RECORD_ID, NULL BATCH_NUMBER,
                   gn_conc_request_id REQUEST_ID, OPERATING_UNIT, NULL NEW_OPERATING_UNIT_ID,
                   NULL NEW_OPERATING_NAME, INVENTORY_ORG, NULL NEW_INVENTORY_ORG_ID,
                   NULL NEW_INVENTORY_ORG_NAME, ITEM_NUMBER, STYLE,
                   INVENTORY_ITEM_ID, NULL NEW_INVENTORY_ITEM_ID, BRAND,
                   VALUE_CATEGORY, COST_TYPE, ONHAND_QTY,
                   ONHAND_SPLIT_QTY, RCV_RECEIPT_NUMBER, RCV_TRANSACTION_ID,
                   RCV_TRANSACTION_DATE, RCV_QUARTER, RCV_QUANTITY,
                   RCV_PO_HEADER_ID, RCV_PO_LINE_ID, RCV_PO_DISTRIBUTION_ID,
                   RCV_PACKING_SLIP, MATCH_TYPE_RCV_TO_INVOICE, INVOICE_NUMBER,
                   INVOICE_DIST_ID, INVOICE_DIST_QTY, INVOICE_DIST_UNIT_PRICE,
                   INVOICE_DIST_AMOUNT, ONHAND_SPLIT_QTY_UNIT_PRICE, ONHAND_SPLIT_QTY_AMOUNT,
                   COMPUTED_ITEM_COST, PERCENT_FREIGHT, UNIT_FREIGHT,
                   FREIGHT_AMOUNT, COMPUTED_FREIGHT_COST, UNIT_OVERHEAD,
                   OVERHEAD_AMOUNT, COMPUTED_OVERHEAD_COST, PERCENT_DUTY,
                   UNIT_DUTY, DUTY_AMOUNT, COMPUTED_DUTY_COST,
                   LAST_UPDATE_DATE, LAST_UPDATED_BY, CREATION_DATE,
                   CREATED_BY, ZONE_TYPE, SUBINVENTORY,
                   LOCATOR_ID, NULL LOCATOR, NULL NEW_LOCATOR_ID
              FROM XXD_CONV.XXD_INV_ITEM_ONHAND_QTY_1206_T XACI
             WHERE     1 = 1                           --cost_type = 'RECEIPT'
                   AND OPERATING_UNIT =
                       NVL (V_OPERATING_UNIT, OPERATING_UNIT)
                   AND INVENTORY_ORG = NVL (V_INVENTORY_ORG, INVENTORY_ORG)
                   AND ONHAND_QTY > 0
                   AND RCV_TRANSACTION_DATE IS NOT NULL
                   AND EXISTS
                           (SELECT 1
                              FROM MTL_SYSTEM_ITEMS_B MSB
                             WHERE MSB.segment1 = XACI.ITEM_NUMBER);
    --
    --              ,cst_item_costs_for_gl_view@bt_read_1206 cst
    --       WHERE cst.organization_id = XACI.INVENTORY_ORG
    --         AND cst.inventory_item_id = XACI.INVENTORY_ITEM_ID(+)
    --        WHERE

    --where customer_id   in ( 2020,1453,2002,2079,2255)     ;
    --AND   HSUA.org_id            = p_source_org_id)        ;



    BEGIN
        gtt_inv_onhand_qty_tab.delete;

        EXECUTE IMMEDIATE 'TRUNCATE TABLE XXD_CONV.XXD_INV_ITEM_ONHAND_QTY_STG_T';

        FOR rec_ou IN lcu_ou
        LOOP
            V_OPERATING_UNIT   := rec_ou.org_id;

            FOR rec_1206_org IN lcu_1206_org
            LOOP
                FOR i IN lcu_inv_org (rec_1206_org.organization_code)
                LOOP
                    V_INVENTORY_ORG   := i.inventory_org_id;

                    OPEN lcu_onhand_qty_data;

                    LOOP
                        lv_error_stage   :=
                            'Inserting Inventory Onhand quantity Data';
                        fnd_file.put_line (fnd_file.LOG, lv_error_stage);
                        gtt_inv_onhand_qty_tab.delete;

                        FETCH lcu_onhand_qty_data
                            BULK COLLECT INTO gtt_inv_onhand_qty_tab
                            LIMIT 5000;

                        FORALL i IN 1 .. gtt_inv_onhand_qty_tab.COUNT
                            INSERT INTO XXD_INV_ITEM_ONHAND_QTY_STG_T
                                 VALUES gtt_inv_onhand_qty_tab (i);

                        COMMIT;
                        EXIT WHEN lcu_onhand_qty_data%NOTFOUND;
                    END LOOP;

                    CLOSE lcu_onhand_qty_data;

                    OPEN lcu_extract_count;

                    FETCH lcu_extract_count INTO x_total_rec;

                    CLOSE lcu_extract_count;
                END LOOP;
            END LOOP;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuf    := SQLERRM;
            x_retcode   := 1;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Inserting record In '
                || lv_error_stage
                || ' : '
                || SQLERRM);
            fnd_file.put_line (fnd_file.LOG, 'Exception ' || SQLERRM);
    END extract_1206_data;

    FUNCTION check_subinv (p_subinv IN VARCHAR2, p_org_id IN NUMBER)
        RETURN BOOLEAN
    /**********************************************************************************************
    *                                                                                             *
    * Function  Name       :  check_subinv                                                        *
    *                                                                                             *
    * Description          :  To check for the existence of secondary inventory                   *
    *                                                                                             *
    * Called From          :                                                                      *
    *                                                                                             *
    * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                         *
    * -----------------------                                                                     *
    * MTL_SECONDARY_INVENTORIES       : S                                                         *
    *                                                                                             *
    *  Change History                                                                             *
    *  -----------------                                                                          *
    *  Version    Date             Author           Description                                   *
    *  ---------  ------------    ---------------   -----------------------------                 *
    *  1.0        25-OCT-2011      Phaneendra V         Initial creation                          *
    *                                                                                             *
    **********************************************************************************************/
    IS
        lc_subinv         mtl_secondary_inventories.secondary_inventory_name%TYPE;
        lc_err_msg        VARCHAR2 (500);
        lc_proc_status    CHAR (1);
        lc_proc_err_msg   VARCHAR2 (1000);
    BEGIN
        log_records (gc_debug_flag, 'Checking for the Subinventory....');

        SELECT secondary_inventory_name
          --         ,material_account
          INTO lc_subinv
          FROM mtl_secondary_inventories
         WHERE     organization_id = p_org_id
               AND UPPER (secondary_inventory_name) = UPPER (p_subinv)
               AND NVL (disable_date, TRUNC (SYSDATE) + 1) > TRUNC (SYSDATE);


        log_records (gc_debug_flag, 'Subinventory is....' || lc_subinv);
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            lc_err_msg   :=
                   'Error in Checking Item SubInventory: '
                || SQLCODE
                || ' - '
                || SQLERRM;

            log_records (p_debug => gc_debug_flag, p_message => lc_err_msg);

            RETURN FALSE;
        --

        WHEN OTHERS
        THEN
            lc_err_msg   :=
                   'Error in Checking Item SubInventory: '
                || SQLCODE
                || ' - '
                || SQLERRM;

            log_records (p_debug => gc_debug_flag, p_message => lc_err_msg);

            RETURN FALSE;
    END check_subinv;                                   -- End Of check_subinv

    --Deriving Serial lot control
    PROCEDURE get_locator_control (p_org_id IN NUMBER --p_org_code          IN   VARCHAR2
                                                     , p_subinventory IN VARCHAR2--                              ,p_item_num                  IN   VARCHAR2
                                                                                 , x_locator_control_code OUT NUMBER)
    /**********************************************************************************************
    *                                                                                             *
    * Procedure  Name       :  get_locator_control                                                *
    *                                                                                             *
    * Description           :  To get Item Information like item_id,Uom_code,Lot_control
                               of an Item in the instance                                         *
    *                                                                                             *
    * Called From           :                                                                     *
    *                                                                                             *
    * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                         *
    * -----------------------                                                                     *
    * MTL_SYSTEM_ITEMS_B              : S                                                         *
    *                                                                                             *
    *  Change History                                                                             *
    *  -----------------                                                                          *
    *  Version    Date             Author           Description                                   *
    *  ---------  ------------    ---------------   -----------------------------                 *
    *  1.0        25-OCT-2011    Phaneendra V         Initial creation                            *
    *                                                                                             *
    **********************************************************************************************/
    IS
        lc_err_msg                VARCHAR2 (500);
        lc_proc_status            VARCHAR2 (1);
        lc_proc_err_msg           VARCHAR2 (1000);
        ln_locator_control_code   mtl_system_items_b.location_control_code%TYPE;
    BEGIN
        log_records (gc_debug_flag, 'Checking Locator Control Code...');

        --
        --    SELECT stock_locator_control_code
        --    INTO   ln_locator_control_code
        --    FROM  mtl_parameters
        --    WHERE  organization_id=p_org_id;
        --
        --      IF ln_locator_control_code=4
        --      THEN
        SELECT locator_type
          INTO ln_locator_control_code
          FROM apps.mtl_secondary_inventories
         WHERE     organization_id = p_org_id
               AND UPPER (secondary_inventory_name) = UPPER (p_subinventory)
               AND NVL (disable_date, TRUNC (SYSDATE) + 1) > TRUNC (SYSDATE);

        --               IF ln_locator_control_code=4 THEN
        --
        --                    SELECT MSI.location_control_code
        --                     INTO   ln_locator_control_code
        --                     FROM   apps.mtl_system_items_b MSI
        --                     WHERE  MSI.organization_id =  p_org_id
        --                     AND    MSI.segment1        =  p_item_num
        --                     AND    MSI.shippable_item_flag = 'Y'
        --                     AND    MSI.inventory_item_flag = 'Y'
        --                     AND    MSI.mtl_transactions_enabled_flag = 'Y'
        ----                     AND    UPPER(MSI.inventory_item_status_code) = 'INACTIVE'
        --                     AND    MSI.serial_number_control_code IN  (SELECT     lookup_code
        --                                                                FROM       apps.mfg_lookups
        --                                                                WHERE      lookup_type = 'MTL_LOCATION_CONTROL'
        --                                                                AND        enabled_flag = 'Y');
        --
        --               END IF;
        --      END IF;

        x_locator_control_code   := ln_locator_control_code;
        log_records (
            gc_debug_flag,
               'Locator Control Code...  1. No locator control ,  <>1 . locator control =>'
            || x_locator_control_code);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            lc_err_msg   :=
                'No data found for serial control and lot control';

            log_records (p_debug => gc_debug_flag, p_message => lc_err_msg);
        WHEN OTHERS
        THEN
            lc_err_msg   := 'Unexpected Error  ' || SQLERRM || '-' || SQLCODE;

            log_records (p_debug => gc_debug_flag, p_message => lc_err_msg);
    END get_locator_control;                  -- End Of get_serial_lot_control

    PROCEDURE get_locator_name (p_inventory_locaton_id   IN     NUMBER,
                                p_org_id                        NUMBER,
                                lx_locator_name             OUT VARCHAR2,
                                lx_new_location_id          OUT NUMBER,
                                lx_new_subinventory         OUT VARCHAR2)
    AS
        -- +=======================================================================+
        -- | Name  : get_locator_name                                              |
        -- | Description      : This procedure  is used to get locator name        |
        -- |                                                                       |
        -- |                                                                       |
        -- | Parameters : p_inventory_locaton_id                                   |
        -- |                                                                       |
        -- |                                                                       |
        -- | Returns : x_org_id                                                    |
        -- |                                                                       |
        -- +=======================================================================+
        lc_conc_code_combn   VARCHAR2 (100);
        l_n_segments         NUMBER := 5;
        l_delim              VARCHAR2 (1) := '.';
        l_segment_array      fnd_flex_ext.segmentarray;
        ln_coa_id            NUMBER;
        l_concat_segs        VARCHAR2 (32000);
    BEGIN
        lx_locator_name       := NULL;
        lx_new_location_id    := NULL;
        lx_new_subinventory   := NULL;

        SELECT segment1, segment2, segment3,
               segment4, segment5
          INTO l_segment_array (1), l_segment_array (2), l_segment_array (3), l_segment_array (4),
                                  l_segment_array (5)
          FROM apps.MTL_ITEM_LOCATIONS@bt_read_1206
         WHERE INVENTORY_LOCATION_ID = p_inventory_locaton_id;

        -- AND  organization_id = p_org_id;

        lx_locator_name       :=
            fnd_flex_ext.concatenate_segments (l_n_segments,
                                               l_segment_array,
                                               l_delim);


        SELECT INVENTORY_LOCATION_ID, SUBINVENTORY_CODE
          INTO lx_new_location_id, lx_new_subinventory
          FROM MTL_ITEM_LOCATIONS_KFV
         WHERE     CONCATENATED_SEGMENTS = lx_locator_name
               AND organization_id = p_org_id;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            NULL;
        WHEN OTHERS
        THEN
            NULL;
    END get_locator_name;

    PROCEDURE inv_onhand_qty_validation (x_retcode OUT NUMBER, x_errbuf OUT VARCHAR2, p_process IN VARCHAR2
                                         , p_batch_number IN NUMBER, P_OPERATING_UNIT IN VARCHAR2, P_INVENTORY_ORG IN VARCHAR2)
    AS
        -- +=======================================================================+
        -- | Name  : inv_onhand_qty_validation                                     |
        -- | Description      : This procedure  is used to validate data           |
        -- |                                                                       |
        -- |                                                                       |
        -- | Parameters : P_OPERATING_UNIT, P_INVENTORY_ORG                        |
        -- |                                                                       |
        -- |                                                                       |
        -- | Returns :                                                             |
        -- |                                                                       |
        -- +=======================================================================+
        PRAGMA AUTONOMOUS_TRANSACTION;
        lc_status                  VARCHAR2 (20);
        ln_cnt                     NUMBER := 0;

        V_INVENTORY_ORG            NUMBER;
        V_OPERATING_UNIT           NUMBER;
        v_Inventory_org_1206       VARCHAR2 (10);
        v_sub_inventory_1223       VARCHAR2 (10);

        CURSOR lcu_ou IS
            SELECT lookup_code org_id
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_1206_OU_MAPPING'
                   AND attribute1 = NVL (P_OPERATING_UNIT, attribute1)
                   AND language = USERENV ('LANG');

        CURSOR lcu_1206_org IS
              SELECT DISTINCT mp.organization_code, mp.organization_id, ood.operating_unit,
                              hou.name
                FROM org_organization_definitions ood, mtl_parameters mp, fnd_lookup_values fl,
                     apps.hr_operating_units hou
               WHERE     ood.organization_id = mp.organization_id
                     AND fl.lookup_type = 'XXD_1206_INV_ORG_MAPPING'
                     AND fl.attribute1(+) = mp.organization_code
                     AND ood.operating_unit = hou.organization_id
                     AND hou.name = P_OPERATING_UNIT
                     AND mp.organization_code =
                         NVL (P_INVENTORY_ORG, mp.organization_code)
            ORDER BY mp.organization_code;

        CURSOR lcu_inv_org (P_INV_ORG VARCHAR2)
        IS
            SELECT TO_NUMBER (lookup_code) inventory_org_id, meaning Inventory_org_1206
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_1206_INV_ORG_MAPPING'
                   AND attribute1 = NVL (P_INV_ORG, attribute1)
                   AND language = USERENV ('LANG');



        CURSOR cu_onhand_qty_data (p_process VARCHAR2)
        IS
            SELECT *
              FROM XXD_INV_ITEM_ONHAND_QTY_STG_T cust
             WHERE     RECORD_STATUS = p_process
                   AND batch_number = p_batch_number
                   AND OPERATING_UNIT =
                       NVL (V_OPERATING_UNIT, OPERATING_UNIT)
                   AND INVENTORY_ORG = NVL (V_INVENTORY_ORG, INVENTORY_ORG);

        TYPE lt_onhand_qty_typ IS TABLE OF cu_onhand_qty_data%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_onhand_qty_data         lt_onhand_qty_typ;
        lc_onhand_qty_valid_data   VARCHAR2 (1) := gc_yes_flag;
        lc_error_msg               VARCHAR2 (2000);


        lx_org_name                VARCHAR2 (250);
        lx_inv_org_name            VARCHAR2 (250);
        lx_org_id                  NUMBER;
        lx_inv_org_id              NUMBER;
        lx_inv_item_id             NUMBER;
        ln_item_cost               NUMBER;
        ln_return_no               NUMBER DEFAULT NULL;
        lv_locator_name            VARCHAR2 (150) DEFAULT NULL;
        ln_new_locator_id          NUMBER DEFAULT NULL;
        lv_new_subinventory_code   VARCHAR2 (10);
        lx_locator_control_code    NUMBER;
    BEGIN
        x_retcode   := NULL;
        x_errbuf    := NULL;
        log_records (
            gc_debug_flag,
            'validate inv_onhand_qty_validation p_process =.  ' || p_process);

        FOR rec_ou IN lcu_ou
        LOOP
            V_OPERATING_UNIT   := rec_ou.org_id;

            FOR rec_1206_org IN lcu_1206_org
            LOOP
                FOR i IN lcu_inv_org (rec_1206_org.organization_code)
                LOOP
                    V_INVENTORY_ORG        := i.inventory_org_id;
                    v_Inventory_org_1206   := i.Inventory_org_1206;

                    OPEN cu_onhand_qty_data (p_process => p_process);

                    LOOP
                        FETCH cu_onhand_qty_data
                            BULK COLLECT INTO lt_onhand_qty_data
                            LIMIT 100;

                        log_records (
                            gc_debug_flag,
                               'validate inv_onhand_qty_validation '
                            || lt_onhand_qty_data.COUNT);

                        EXIT WHEN lt_onhand_qty_data.COUNT = 0;

                        IF lt_onhand_qty_data.COUNT > 0
                        THEN
                            FOR xc_inv_qty_rec IN lt_onhand_qty_data.FIRST ..
                                                  lt_onhand_qty_data.LAST
                            LOOP
                                lc_onhand_qty_valid_data   := gc_yes_flag;
                                lc_error_msg               := NULL;
                                lx_inv_org_id              := NULL;
                                lx_inv_item_id             := NULL;
                                get_org_id (
                                    p_org_name_id   =>
                                        lt_onhand_qty_data (xc_inv_qty_rec).OPERATING_UNIT,
                                    x_org_name   => lx_org_name,
                                    x_org_id     => lx_org_id);


                                get_inv_org_id (
                                    p_inv_org_name_id   =>
                                        lt_onhand_qty_data (xc_inv_qty_rec).INVENTORY_ORG,
                                    x_inv_org_name   => lx_inv_org_name,
                                    x_inv_org_id     => lx_inv_org_id);



                                -- Inventory Item validatoin

                                IF lx_inv_org_id IS NOT NULL
                                THEN
                                    BEGIN
                                        SELECT inventory_item_id
                                          INTO lx_inv_item_id
                                          FROM MTL_SYSTEM_ITEMS_B
                                         WHERE     segment1 =
                                                   lt_onhand_qty_data (
                                                       xc_inv_qty_rec).ITEM_NUMBER
                                               AND organization_id =
                                                   lx_inv_org_id;
                                    EXCEPTION
                                        WHEN NO_DATA_FOUND
                                        THEN
                                            lc_onhand_qty_valid_data   :=
                                                gc_no_flag;
                                            xxd_common_utils.record_error (
                                                'INV',
                                                gn_org_id,
                                                'Decker Inventory Item Onhand Conversion Program',
                                                --      SQLCODE,
                                                SQLERRM,
                                                DBMS_UTILITY.format_error_backtrace,
                                                --   DBMS_UTILITY.format_call_stack,
                                                --    SYSDATE,
                                                gn_user_id,
                                                gn_conc_request_id,
                                                'INVALID ITEM',
                                                lt_onhand_qty_data (
                                                    xc_inv_qty_rec).ITEM_NUMBER,
                                                   'ITEM_NUMBER '
                                                || lt_onhand_qty_data (
                                                       xc_inv_qty_rec).ITEM_NUMBER
                                                || ' Not available for the org '
                                                || lx_inv_org_name
                                                || ' '
                                                || SQLERRM);
                                        WHEN OTHERS
                                        THEN
                                            lc_onhand_qty_valid_data   :=
                                                gc_no_flag;
                                            xxd_common_utils.record_error (
                                                'INV',
                                                gn_org_id,
                                                'Decker Inventory Item Onhand Conversion Program',
                                                --      SQLCODE,
                                                SQLERRM,
                                                DBMS_UTILITY.format_error_backtrace,
                                                --   DBMS_UTILITY.format_call_stack,
                                                --    SYSDATE,
                                                gn_user_id,
                                                gn_conc_request_id,
                                                'INVALID ITEM',
                                                lt_onhand_qty_data (
                                                    xc_inv_qty_rec).ITEM_NUMBER,
                                                   'ITEM_NUMBER '
                                                || lt_onhand_qty_data (
                                                       xc_inv_qty_rec).ITEM_NUMBER
                                                || ' Not available for the org '
                                                || lx_inv_org_name
                                                || ' '
                                                || SQLERRM);
                                    END;

                                    IF lt_onhand_qty_data (xc_inv_qty_rec).subinventory
                                           IS NOT NULL
                                    THEN
                                        BEGIN
                                            SELECT sub_inventory_1223
                                              INTO v_sub_inventory_1223
                                              FROM XXD_1206_SUBINV_LOC_MAPPING
                                             WHERE     sub_inventory_1206 =
                                                       lt_onhand_qty_data (
                                                           xc_inv_qty_rec).subinventory
                                                   AND org_code_1206 =
                                                       v_Inventory_org_1206;
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                v_sub_inventory_1223   :=
                                                    NULL;
                                                log_records (
                                                    gc_debug_flag,
                                                       'ERROR validate inv_onhand_qty_validation fetching 1223 Subinv:'
                                                    || SQLERRM);
                                        END;

                                        IF v_sub_inventory_1223 = 'NA'
                                        THEN
                                            v_sub_inventory_1223   :=
                                                'RECEIVING';
                                        END IF;

                                        IF NOT check_subinv (
                                                   p_subinv   =>
                                                       v_sub_inventory_1223,
                                                   p_org_id   => lx_inv_org_id)
                                        THEN
                                            lc_onhand_qty_valid_data   :=
                                                gc_no_flag;

                                            xxd_common_utils.record_error (
                                                'INV',
                                                gn_org_id,
                                                'Decker Inventory Item Onhand Conversion Program',
                                                --      SQLCODE,
                                                SQLERRM,
                                                DBMS_UTILITY.format_error_backtrace,
                                                --   DBMS_UTILITY.format_call_stack,
                                                --    SYSDATE,
                                                gn_user_id,
                                                gn_conc_request_id,
                                                'INVALID subinventory',
                                                v_sub_inventory_1223,
                                                   'No Mapping subinventory for '
                                                || lt_onhand_qty_data (
                                                       xc_inv_qty_rec).subinventory
                                                || ' Defined in the system FOR INV org '
                                                || lx_inv_org_id);
                                        ELSE
                                            get_locator_control (
                                                p_org_id   => lx_inv_org_id --p_org_code          IN   VARCHAR2
                                                                           ,
                                                p_subinventory   =>
                                                    v_sub_inventory_1223 --lt_onhand_qty_data(xc_inv_qty_rec).SUBINVENTORY
                                                                        ,
                                                x_locator_control_code   =>
                                                    lx_locator_control_code);
                                        END IF;



                                        IF lx_locator_control_code <> 1
                                        THEN
                                            get_locator_name (
                                                p_inventory_locaton_id   =>
                                                    lt_onhand_qty_data (
                                                        xc_inv_qty_rec).locator_id,
                                                p_org_id   => lx_inv_org_id,
                                                lx_locator_name   =>
                                                    lv_locator_name,
                                                lx_new_location_id   =>
                                                    ln_new_locator_id,
                                                lx_new_subinventory   =>
                                                    lv_new_subinventory_code);

                                            IF ln_new_locator_id IS NULL
                                            THEN
                                                lc_onhand_qty_valid_data   :=
                                                    gc_no_flag;
                                                xxd_common_utils.record_error (
                                                    'INV',
                                                    gn_org_id,
                                                    'Decker Inventory Item Onhand Conversion Program',
                                                    --      SQLCODE,
                                                    SQLERRM,
                                                    DBMS_UTILITY.format_error_backtrace,
                                                    --   DBMS_UTILITY.format_call_stack,
                                                    --    SYSDATE,
                                                    gn_user_id,
                                                    gn_conc_request_id,
                                                    'INVALID LOCATOR_NAME',
                                                       lv_locator_name
                                                    || '-'
                                                    || rec_1206_org.organization_code
                                                    || '-'
                                                    || v_sub_inventory_1223,
                                                       'No LOCATOR_NAME  '
                                                    || lt_onhand_qty_data (
                                                           xc_inv_qty_rec).locator_id
                                                    || ' Defined in the system ');
                                            END IF;
                                        ELSE
                                            ln_new_locator_id   := NULL;
                                            lv_new_subinventory_code   :=
                                                v_sub_inventory_1223;
                                        END IF;
                                    ELSE
                                        ln_new_locator_id          := NULL;
                                        lv_new_subinventory_code   := NULL;
                                    END IF;
                                END IF;

                                /*  IF lx_inv_item_id IS NOT NULL THEN

                                  BEGIN
                                  SELECT cst.material_cost
                                  INTO ln_item_cost
                                   FROM XXD_CONV.XXD_CST_ITEM_COSTS_GL_1206_T cst
                                  WHERE cst.organization_id = lt_onhand_qty_data(xc_inv_qty_rec).INVENTORY_ORG
                                    AND cst.inventory_item_id = lt_onhand_qty_data(xc_inv_qty_rec).INVENTORY_ITEM_ID;
                                  EXCEPTION
                                  WHEN OTHERS THEN
                                    ln_item_cost := NULL;
                                  END ;
                                  END IF;*/
                                IF lx_org_name IS NULL
                                THEN
                                    lc_onhand_qty_valid_data   := gc_no_flag;
                                    xxd_common_utils.record_error (
                                        'INV',
                                        gn_org_id,
                                        'Decker Inventory Item Onhand Conversion Program',
                                        --      SQLCODE,
                                        SQLERRM,
                                        DBMS_UTILITY.format_error_backtrace,
                                        --   DBMS_UTILITY.format_call_stack,
                                        --    SYSDATE,
                                        gn_user_id,
                                        gn_conc_request_id,
                                        'INVALID OPERATING_UNIT',
                                        lt_onhand_qty_data (xc_inv_qty_rec).OPERATING_UNIT,
                                           'No OPERATING_UNIT mapping '
                                        || lt_onhand_qty_data (
                                               xc_inv_qty_rec).OPERATING_UNIT
                                        || ' Defined in the system ');
                                END IF;

                                IF lx_inv_org_name IS NULL
                                THEN
                                    lc_onhand_qty_valid_data   := gc_no_flag;
                                    xxd_common_utils.record_error (
                                        'INV',
                                        gn_org_id,
                                        'Decker Inventory Item Onhand Conversion Program',
                                        --      SQLCODE,
                                        SQLERRM,
                                        DBMS_UTILITY.format_error_backtrace,
                                        --   DBMS_UTILITY.format_call_stack,
                                        --    SYSDATE,
                                        gn_user_id,
                                        gn_conc_request_id,
                                        'INVALID INVENTORY_ORG',
                                        lt_onhand_qty_data (xc_inv_qty_rec).INVENTORY_ORG,
                                           'No INVENTORY_ORG mapping '
                                        || lt_onhand_qty_data (
                                               xc_inv_qty_rec).INVENTORY_ORG
                                        || ' Defined in the system ');
                                END IF;


                                IF lc_onhand_qty_valid_data = gc_yes_flag
                                THEN
                                    UPDATE XXD_INV_ITEM_ONHAND_QTY_STG_T
                                       SET NEW_OPERATING_UNIT_ID = lx_org_id, NEW_OPERATING_NAME = lx_org_name, NEW_INVENTORY_ORG_ID = lx_inv_org_id,
                                           NEW_INVENTORY_ORG_NAME = lx_inv_org_name, NEW_INVENTORY_ITEM_ID = lx_inv_item_id, --  COMPUTED_ITEM_COST              = ln_item_cost,
                                                                                                                             RECORD_STATUS = gc_validate_status,
                                           LOCATOR = lv_locator_name, new_locator_id = ln_new_locator_id, SUBINVENTORY = lv_new_subinventory_code
                                     WHERE     record_id =
                                               lt_onhand_qty_data (
                                                   xc_inv_qty_rec).record_id
                                           AND batch_number =
                                               lt_onhand_qty_data (
                                                   xc_inv_qty_rec).batch_number;
                                ELSE
                                    UPDATE XXD_INV_ITEM_ONHAND_QTY_STG_T
                                       SET NEW_OPERATING_UNIT_ID = lx_org_id, NEW_OPERATING_NAME = lx_org_name, NEW_INVENTORY_ORG_ID = lx_inv_org_id,
                                           NEW_INVENTORY_ORG_NAME = lx_inv_org_name, -- COMPUTED_ITEM_COST              = ln_item_cost,
                                                                                     NEW_INVENTORY_ITEM_ID = lx_inv_item_id, RECORD_STATUS = gc_error_status
                                     WHERE     record_id =
                                               lt_onhand_qty_data (
                                                   xc_inv_qty_rec).record_id
                                           AND batch_number =
                                               lt_onhand_qty_data (
                                                   xc_inv_qty_rec).batch_number;
                                END IF;
                            END LOOP;
                        END IF;

                        COMMIT;
                    END LOOP;

                    CLOSE cu_onhand_qty_data;
                END LOOP;
            END LOOP;
        END LOOP;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_retcode   := 2;
            x_errbuf    := x_errbuf || SQLERRM;
            ROLLBACK;
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Exception Raised During inv_onhand_qty_validation Validation Program');
            ROLLBACK;
            x_retcode   := 2;
            x_errbuf    := x_errbuf || SQLERRM;
    END inv_onhand_qty_validation;


    PROCEDURE submit_po_request (p_batch_id        IN     NUMBER,
                                 p_org_id          IN     NUMBER,
                                 p_submit_openpo      OUT VARCHAR2)
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

        lc_openpo_hdr_phase        VARCHAR2 (50);
        lc_openpo_hdr_status       VARCHAR2 (100);
        lc_openpo_hdr_dev_phase    VARCHAR2 (100);
        lc_openpo_hdr_dev_status   VARCHAR2 (100);
        lc_openpo_hdr_message      VARCHAR2 (3000);
        lc_submit_openpo           VARCHAR2 (10) := 'N';
        lb_openpo_hdr_req_wait     BOOLEAN;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'p_batch_id:' || p_batch_id);
        log_records (gc_debug_flag,
                     'Seeded Open PO import program POXPOPDOI');
        --fnd_client_info.set_org_context (location_dtl.TARGET_ORG);
        -- FND_REQUEST.SET_ORG_ID(p_org_id);
        FND_GLOBAL.APPS_INITIALIZE (FND_GLOBAL.USER_ID, 20707, 201);
        --FND_GLOBAL.APPS_INITIALIZE(FND_GLOBAL.USER_ID,FND_GLOBAL.RESP_ID,FND_GLOBAL.RESP_APPL_ID);
        fnd_file.put_line (fnd_file.LOG, 'p_org_id:' || p_org_id);
        MO_GLOBAL.init ('PO');
        mo_global.set_policy_context ('S', p_org_id);
        FND_REQUEST.SET_ORG_ID (p_org_id);
        DBMS_APPLICATION_INFO.set_client_info (p_org_id);
        fnd_file.put_line (fnd_file.LOG,
                           'Profile org_id:' || fnd_profile.VALUE ('ORG_ID'));
        --if p_batch_id= 132 THEN
        ln_request_id   :=
            fnd_request.submit_request (application   => gc_appl_shrt_name,
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
                                        argument8     => p_batch_id,
                                        argument9     => NULL,
                                        argument10    => 'N',
                                        argument11    => NULL,
                                        argument12    => NULL,
                                        argument13    => 'Y');
        NULL;
        COMMIT;

        --end if;
        IF ln_request_id = 0
        THEN
            log_records (gc_debug_flag,
                         'Seeded Open PO import program POXPOPDOI failed ');
        ELSE
            -- wait for request to complete.
            lc_openpo_hdr_dev_phase   := NULL;
            lc_openpo_hdr_phase       := NULL;

            /*     LOOP

                    lb_openpo_hdr_req_wait   := FND_CONCURRENT.WAIT_FOR_REQUEST(
                                                              request_id   => ln_request_id
                                                             ,interval     => 1
                                                             ,max_wait     => 1
                                                             ,phase        => lc_openpo_hdr_phase
                                                             ,status       => lc_openpo_hdr_status
                                                             ,dev_phase    => lc_openpo_hdr_dev_phase
                                                             ,dev_status   => lc_openpo_hdr_dev_status
                                                             ,message      => lc_openpo_hdr_message
                                                             );

                    IF ((UPPER(lc_openpo_hdr_dev_phase) = 'COMPLETE')  OR (UPPER(lc_openpo_hdr_phase) = 'COMPLETED')) THEN

                       lc_submit_openpo := 'Y';

                       log_records (gc_debug_flag, ' Open PO Import debug: request_id: '||ln_request_id||', lc_openpo_hdr_dev_phase: '||lc_openpo_hdr_dev_phase||',lc_openpo_hdr_phase: '||lc_openpo_hdr_phase);

                       EXIT;

                    END IF;

                 END LOOP;*/

            p_submit_openpo           := lc_submit_openpo;
        END IF;
    END submit_po_request;

    PROCEDURE submit_rcv_request (p_batch_id      IN     NUMBER,
                                  p_org_id        IN     NUMBER,
                                  p_submit_flag      OUT VARCHAR2)
    -- +===================================================================+
    -- | Name  : SUBMIT_PO_REQUEST                                         |
    -- | Description      : Main Procedure to submit the purchase order    |
    -- |                    request                                        |
    -- |                                                                   |
    -- | Parameters : p_submit_flag                                        |
    -- |                                                                   |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :                                                         |
    -- |                                                                   |
    -- +===================================================================+
    IS
        ln_request_id              NUMBER := 0;

        lc_openpo_hdr_phase        VARCHAR2 (50);
        lc_openpo_hdr_status       VARCHAR2 (100);
        lc_openpo_hdr_dev_phase    VARCHAR2 (100);
        lc_openpo_hdr_dev_status   VARCHAR2 (100);
        lc_openpo_hdr_message      VARCHAR2 (3000);
        lc_submit_openpo           VARCHAR2 (10) := 'N';
        lb_openpo_hdr_req_wait     BOOLEAN;
    BEGIN
        --fnd_client_info.set_org_context (location_dtl.TARGET_ORG);
        -- FND_REQUEST.SET_ORG_ID(p_org_id);
        FND_GLOBAL.APPS_INITIALIZE (FND_GLOBAL.USER_ID, 20707, 201);
        --FND_GLOBAL.APPS_INITIALIZE(FND_GLOBAL.USER_ID,FND_GLOBAL.RESP_ID,FND_GLOBAL.RESP_APPL_ID);
        fnd_file.put_line (fnd_file.LOG, 'p_org_id:' || p_org_id);
        MO_GLOBAL.init ('PO');
        mo_global.set_policy_context ('S', p_org_id);
        FND_REQUEST.SET_ORG_ID (p_org_id);
        DBMS_APPLICATION_INFO.set_client_info (p_org_id);


        ln_request_id   :=
            fnd_request.submit_request (
                application   => gc_appl_shrt_name,
                program       => gc_rcv_prog_shrt_name,
                description   => NULL,
                start_time    => NULL,
                sub_request   => FALSE,
                argument1     => 'BATCH',
                argument2     => p_batch_id,
                argument3     => NULL                               --p_org_id
                                     );
        COMMIT;

        IF ln_request_id = 0
        THEN
            log_records (
                gc_debug_flag,
                'Seeded Receiving Transaction Processor program  failed ');
        ELSE
            -- wait for request to complete.
            lc_openpo_hdr_dev_phase   := NULL;
            lc_openpo_hdr_phase       := NULL;

            /*  LOOP

                 lb_openpo_hdr_req_wait   := FND_CONCURRENT.WAIT_FOR_REQUEST(
                                                           request_id   => ln_request_id
                                                          ,interval     => 1
                                                          ,max_wait     => 1
                                                          ,phase        => lc_openpo_hdr_phase
                                                          ,status       => lc_openpo_hdr_status
                                                          ,dev_phase    => lc_openpo_hdr_dev_phase
                                                          ,dev_status   => lc_openpo_hdr_dev_status
                                                          ,message      => lc_openpo_hdr_message
                                                          );

                 IF ((UPPER(lc_openpo_hdr_dev_phase) = 'COMPLETE')  OR (UPPER(lc_openpo_hdr_phase) = 'COMPLETED')) THEN

                    lc_submit_openpo := 'Y';

                    log_records (gc_debug_flag, 'Receiving Transaction Processor debug: request_id: '||ln_request_id||', lc_openpo_hdr_dev_phase: '||lc_openpo_hdr_dev_phase||',lc_openpo_hdr_phase: '||lc_openpo_hdr_phase);

                    EXIT;

                 END IF;

              END LOOP;*/

            p_submit_flag             := lc_submit_openpo;
        END IF;
    END submit_rcv_request;


    PROCEDURE transfer_po_line_records (x_ret_code OUT VARCHAR2, p_operating_unit VARCHAR2, p_inventory_org VARCHAR2)
    /**********************************************************************************************
    *                                                                                             *
    * Procedure Name       :  transfer_po_line_records                                            *
    *                                                                                             *
    * Description          :  This procedure will populate the po_lines_interface program         *
    *                                                                                             *
    * Parameters         Type       Description                                                   *
    * ---------------    ----       ---------------------                                         *
    * x_ret_code         OUT        Return Code                                                   *
    * x_rec_count        OUT        No of records transferred to interface table                  *
    * x_int_run_id       OUT        Interface Run Id                                              *
    *                                                                                             *
    *                                                                                             *
    **********************************************************************************************/
    IS
        TYPE type_po_line_t IS TABLE OF po_lines_interface%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_po_line_type              type_po_line_t;

        TYPE type_po_header_t IS TABLE OF po_headers_interface%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_po_headre_type            type_po_header_t;


        ln_valid_rec_cnt             NUMBER := 0;
        ln_line_rec_cnt              NUMBER := 0;
        ln_count                     NUMBER := 0;
        ln_int_run_id                NUMBER;
        l_bulk_errors                NUMBER := 0;
        lx_interface_line_id         NUMBER := 0;
        lx_interface_header_id       NUMBER := 0;

        ln_organization_id           NUMBER := 0;
        ln_ship_to_organization_id   NUMBER := 0;

        lc_submit_openpo             VARCHAR2 (10) := 'N';
        v_agent_name                 VARCHAR2 (4000);
        v_vendor_name                VARCHAR2 (4000);
        v_vendor_site                VARCHAR2 (4000);
        v_currency_code              VARCHAR2 (10);
        v_ship_to_location           VARCHAR2 (4000);
        v_bill_to_location           VARCHAR2 (4000);
        v_chk_flag                   VARCHAR2 (1) := 'Y';
        v_inventory_org_id           NUMBER;
        v_organization_id            NUMBER;

        ex_bulk_exceptions           EXCEPTION;
        PRAGMA EXCEPTION_INIT (ex_bulk_exceptions, -24381);

        ex_program_exception         EXCEPTION;

        CURSOR c_iorg (c_operating_unit VARCHAR2, c_inventory_org VARCHAR2)
        IS
            SELECT ood.organization_id, ood.operating_unit
              FROM hr_operating_units hou, org_organization_definitions ood
             WHERE     HOU.ORGANIZATION_ID = ood.operating_unit
                   AND hou.name = NVL (c_operating_unit, hou.name)
                   AND ood.organization_code =
                       NVL (c_inventory_org, ood.organization_code);

        --------------------------------------------------------
        --Cursor to fetch the valid records from staging table
        ----------------------------------------------------------
        CURSOR c_get_valid_rec IS
              /* SELECT XPOL.*
               FROM   XXD_INV_ITEM_ONHAND_PO_STG_T XPOL
               WHERE  XPOL.record_status     = gc_validate_status
               ORDER BY ORGANIZATION_ID ,SHIP_TO_ORGANIZATION_ID ,NEED_BY_DATE;*/
              SELECT ORGANIZATION_ID, ITEM, ITEM_ID,
                     SUM (QUANTITY) QUANTITY, UNIT_PRICE, TRUNC (NEED_BY_DATE) NEED_BY_DATE,
                     TRUNC (PROMISED_DATE) PROMISED_DATE, SHIP_TO_ORGANIZATION_ID, SUBINVENTORY,
                     new_locator_id
                FROM XXD_INV_ITEM_ONHAND_PO_STG_T XPOL
               WHERE     XPOL.record_status = gc_validate_status
                     AND RETURN_SUBINV_PO IS NULL
                     AND ORGANIZATION_ID = v_organization_id
                     AND SHIP_TO_ORGANIZATION_ID =
                         NVL (v_inventory_org_id, SHIP_TO_ORGANIZATION_ID)
            --AND ITEM_ID='10639138'
            GROUP BY ORGANIZATION_ID, SUBINVENTORY, ITEM_ID,
                     ITEM, NEW_LOCATOR_ID, SHIP_TO_ORGANIZATION_ID,
                     TRUNC (NEED_BY_DATE), TRUNC (PROMISED_DATE), UNIT_PRICE
            ORDER BY ORGANIZATION_ID, SHIP_TO_ORGANIZATION_ID, NEED_BY_DATE;

        TYPE type_po_stg_t IS TABLE OF c_get_valid_rec%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_po_stg_tab_type           type_po_stg_t;

        TYPE organization_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        lt_org_id                    organization_table;
        ln_cnt                       NUMBER := 0;

        TYPE group_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        lt_batch_id                  group_table;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'AFTER Begin');
        x_ret_code   := gn_suc_const;
        log_records (gc_debug_flag,
                     'Start of transfer_po_line_records procedure');

        lt_po_line_type.DELETE;
        lt_po_stg_tab_type.DELETE;

        --fnd_file.put_line (fnd_file.LOG, 'p_operating_unit:'||p_operating_unit);
        --fnd_file.put_line (fnd_file.LOG, 'p_inventory_org:'||p_inventory_org);
        FOR i IN c_iorg (p_operating_unit, p_inventory_org)
        LOOP
            v_organization_id    := i.operating_unit;
            v_inventory_org_id   := i.organization_id;

            -- fnd_file.put_line (fnd_file.LOG, 'Inside cursor:');
            -- fnd_file.put_line (fnd_file.LOG, 'v_organization_id:'||v_organization_id);
            --fnd_file.put_line (fnd_file.LOG, 'v_inventory_org_id:'||v_inventory_org_id);

            OPEN c_get_valid_rec;

            LOOP
                FETCH c_get_valid_rec
                    BULK COLLECT INTO lt_po_stg_tab_type
                    LIMIT 3000;

                --         SAVEPOINT INSERT_TABLE2;
                ln_valid_rec_cnt   := 0;
                fnd_file.put_line (fnd_file.LOG,
                                   'count:' || lt_po_stg_tab_type.COUNT);

                --IF lt_po_stg_tab_type.count>0 THEN

                FOR cust_idx IN 1 .. lt_po_stg_tab_type.COUNT
                LOOP
                    IF v_chk_flag = 'Y'
                    THEN
                        --FOR rec_get_rec IN c_get_rec(lt_po_stg_tab_type(cust_idx).ORGANIZATION_ID) LOOP

                        -- fnd_file.put_line (fnd_file.LOG, 'v_chk_flag:'||v_chk_flag);
                        -------------------------------------------------------------------------------
                        --Query to fetch the Primary SHIP_TO_LOCATION AND BILL_TO_LOCATION Based on OU
                        -------------------------------------------------------------------------------
                        BEGIN
                            SELECT attribute1 ship_to_location
                              INTO v_ship_to_location
                              FROM fnd_lookup_values
                             WHERE     lookup_type =
                                       'XXD_INV_ONHAND_CONV_LOOKUP'
                                   AND lookup_code =
                                       TO_CHAR (
                                           lt_po_stg_tab_type (cust_idx).ORGANIZATION_ID)
                                   AND language = USERENV ('LANG');
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                v_ship_to_location   := NULL;
                                log_records (
                                    gc_debug_flag,
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception fetching ship to Location in transfer_records procedure ');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Exception fetching ship to Location in transfer_records procedure ');
                                RAISE ex_program_exception;
                        END;

                        BEGIN
                            SELECT attribute2 Bill_to_location
                              INTO v_bill_to_location
                              FROM fnd_lookup_values
                             WHERE     lookup_type =
                                       'XXD_INV_ONHAND_CONV_LOOKUP'
                                   AND lookup_code =
                                       TO_CHAR (
                                           lt_po_stg_tab_type (cust_idx).ORGANIZATION_ID)
                                   AND language = USERENV ('LANG');
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                v_bill_to_location   := NULL;
                                log_records (
                                    gc_debug_flag,
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception fetching Bill to Location in transfer_records procedure ');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Exception fetching Bill to Location in transfer_records procedure ');
                                RAISE ex_program_exception;
                        END;

                        -------------------------------------------------------------------------------
                        --Query to fetch the CURRENCY_CODE based on OU
                        -------------------------------------------------------------------------------
                        BEGIN
                            SELECT CUR.CURRENCY_CODE
                              INTO v_currency_code
                              FROM FINANCIALS_SYSTEM_PARAMS_ALL FSPA, GL_SETS_OF_BOOKS SOB, FND_CURRENCIES CUR
                             WHERE     FSPA.SET_OF_BOOKS_ID =
                                       SOB.SET_OF_BOOKS_ID
                                   AND CUR.CURRENCY_CODE = SOB.CURRENCY_CODE
                                   AND FSPA.ORG_ID =
                                       lt_po_stg_tab_type (cust_idx).ORGANIZATION_ID;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                v_currency_code   := NULL;
                                log_records (
                                    gc_debug_flag,
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception fetching Currency Code in transfer_records procedure ');
                        END;

                        -------------------------------------------------------------------------------
                        --Query to fetch the AGENT_NAME based on OU user login
                        -------------------------------------------------------------------------------
                        BEGIN
                            SELECT P.FULL_NAME Agent_name
                              INTO v_agent_name
                              FROM PER_PEOPLE_F P, PO_AGENTS PA, FND_USER fu
                             WHERE     PA.AGENT_ID = P.PERSON_ID
                                   AND p.PERSON_ID = fu.EMPLOYEE_ID
                                   AND fu.user_id =
                                       fnd_profile.VALUE ('USER_ID');
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                v_agent_name   := 'Stewart, Celene';
                                log_records (
                                    gc_debug_flag,
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception fetching Agent Name in transfer_records procedure .So default it to Stewart, Celene ');
                                fnd_file.put_line (fnd_file.LOG,
                                                   'Invalid Agent Name ');
                        END;

                        -------------------------------------------------------------------------------
                        --Query to fetch the VENDOR_NAME based on Lookup Value
                        -------------------------------------------------------------------------------
                        BEGIN
                            SELECT meaning
                              INTO v_vendor_name
                              FROM fnd_lookup_values
                             WHERE     lookup_type =
                                       'XXD_INV_ONHAND_CONV_LOOKUP'
                                   AND lookup_code = 'VENDOR_NAME'
                                   AND language = USERENV ('LANG');
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                v_vendor_name   := NULL;
                                log_records (
                                    gc_debug_flag,
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception fetching Vendor Name in transfer_records procedure ');
                                fnd_file.put_line (fnd_file.LOG,
                                                   'Invalid Vendor Name ');
                        END;

                        -------------------------------------------------------------------------------
                        --Query to fetch the VENDOR_SITE_CODE based on Lookup Value
                        -------------------------------------------------------------------------------
                        BEGIN
                            SELECT meaning
                              INTO v_vendor_site
                              FROM fnd_lookup_values
                             WHERE     lookup_type =
                                       'XXD_INV_ONHAND_CONV_LOOKUP'
                                   AND lookup_code = 'VENDOR_SITE'
                                   AND language = USERENV ('LANG');
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                v_vendor_site   := NULL;
                                log_records (
                                    gc_debug_flag,
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception fetching Vendor Site Name in transfer_records procedure ');
                                fnd_file.put_line (fnd_file.LOG,
                                                   'Invalid Vendor Site');
                        END;

                        --
                        v_chk_flag   := 'N';
                    --END LOOP;
                    END IF;

                    fnd_file.put_line (fnd_file.LOG,
                                       'v_chk_flag last:' || v_chk_flag);
                    lt_po_headre_type.delete;
                    --   log_records (gc_debug_flag,'Row count :'||ln_valid_rec_cnt);

                    --        IF ln_organization_id <> lt_po_stg_tab_type(cust_idx).ORGANIZATION_ID
                    --        OR ln_ship_to_organization_id <> lt_po_stg_tab_type(cust_idx).SHIP_TO_ORGANIZATION_ID THEN
                    --
                    -- IF ln_organization_id <> lt_po_stg_tab_type(cust_idx).ORGANIZATION_ID  THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'ln_valid_rec_cnt :' || ln_valid_rec_cnt);

                    IF ln_valid_rec_cnt = 0
                    THEN
                        ln_count               := ln_count + 1;
                        ln_line_rec_cnt        := 0;
                        ln_valid_rec_cnt       := 1;  --ln_valid_rec_cnt + 1 ;
                        lt_po_line_type.delete;
                        ln_organization_id     :=
                            lt_po_stg_tab_type (cust_idx).ORGANIZATION_ID;
                        lt_org_id (ln_count)   := ln_organization_id;
                        lt_batch_id (ln_count)   :=
                            PO_CONTROL_GROUPS_S.NEXTVAL;

                        --END IF;
                        ln_ship_to_organization_id   :=
                            lt_po_stg_tab_type (cust_idx).SHIP_TO_ORGANIZATION_ID;
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'lt_org_id (ln_count)  :' || ln_organization_id);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'ln_valid_rec_cnt :' || ln_valid_rec_cnt);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'lt_batch_id (ln_count) :'
                            || lt_batch_id (ln_count));
                        log_records (
                            gc_debug_flag,
                               'lt_batch_id (ln_count) =>'
                            || lt_batch_id (ln_count));
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'userid : ' || fnd_profile.VALUE ('USER_ID'));

                        BEGIN
                            SELECT po_headers_interface_s.NEXTVAL
                              INTO lx_interface_header_id
                              FROM DUAL;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                xxd_common_utils.record_error (
                                    'PO',
                                    gn_org_id,
                                    'XXD Open Purchase Orders Conversion Program',
                                    --  SQLCODE,
                                    SQLERRM,
                                    DBMS_UTILITY.format_error_backtrace,
                                    --   DBMS_UTILITY.format_call_stack,
                                    --   SYSDATE,
                                    gn_user_id,
                                    gn_conc_request_id,
                                    'transfer_po_header_records',
                                    NULL,
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception fetching group id in transfer_records procedure ');
                                log_records (
                                    gc_debug_flag,
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception fetching group id in transfer_records procedure ');
                                RAISE ex_program_exception;
                        END;

                        log_records (
                            gc_debug_flag,
                               'INTERFACE_HEADER_ID =>'
                            || lx_interface_header_id);



                        ----------------Collect PO header Records from stage table--------------
                        lt_po_headre_type (ln_valid_rec_cnt).INTERFACE_HEADER_ID   :=
                            lx_interface_header_id; --rec_get_valid_rec.INTERFACE_HEADER_ID    ;
                        lt_po_headre_type (ln_valid_rec_cnt).BATCH_ID   :=
                            lt_batch_id (ln_count); --rec_get_valid_rec.BATCH_ID    ;
                        lt_po_headre_type (ln_valid_rec_cnt).ACTION   :=
                            'ORIGINAL';        --rec_get_valid_rec.ACTION    ;
                        lt_po_headre_type (ln_valid_rec_cnt).ORG_ID   :=
                            lt_po_stg_tab_type (cust_idx).ORGANIZATION_ID;
                        lt_po_headre_type (ln_valid_rec_cnt).DOCUMENT_TYPE_CODE   :=
                            'STANDARD'; --rec_get_valid_rec.DOCUMENT_SUBTYPE    ;
                        --            lt_po_headre_type(ln_valid_rec_cnt).DOCUMENT_NUM                            :=        rec_get_valid_rec.DOCUMENT_NUM    ;
                        lt_po_headre_type (ln_valid_rec_cnt).PO_HEADER_ID   :=
                            PO_HEADERS_S.NEXTVAL;

                        lt_po_headre_type (ln_valid_rec_cnt).CURRENCY_CODE   :=
                            v_currency_code; --'USD';--rec_get_valid_rec.CURRENCY_CODE    ;
                        lt_po_headre_type (ln_valid_rec_cnt).AGENT_NAME   :=
                            v_agent_name; --'Stewart, Celene';--rec_get_valid_rec.AGENT_NAME    ;
                        lt_po_headre_type (ln_valid_rec_cnt).VENDOR_NAME   :=
                            v_vendor_name; --'DURAMAS, S.A. DE C.V.';--rec_get_valid_rec.VENDOR_NAME    ;
                        lt_po_headre_type (ln_valid_rec_cnt).VENDOR_SITE_CODE   :=
                            v_vendor_site; --'DURAMAS';--rec_get_valid_rec.VENDOR_SITE_CODE    ;
                        lt_po_headre_type (ln_valid_rec_cnt).SHIP_TO_LOCATION   :=
                            v_ship_to_location; --'US - DC1 Ventura' ;--rec_get_valid_rec.SHIP_TO_LOCATION    ;
                        lt_po_headre_type (ln_valid_rec_cnt).BILL_TO_LOCATION   :=
                            v_bill_to_location; --'Deckers US, Goleta';--rec_get_valid_rec.BILL_TO_LOCATION    ;


                        -------------------------------------------------------------------
                        -- do a bulk insert into the po_headers_interface table for the batch
                        ----------------------------------------------------------------
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Before inserting PO HEADER INTERFACE TABLE :');

                        FORALL ln_cnt IN 1 .. lt_po_headre_type.COUNT
                          SAVE EXCEPTIONS
                            INSERT INTO po_headers_interface
                                 VALUES lt_po_headre_type (ln_cnt);

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'AFTER inserting PO Header Table :');

                        INSERT INTO XXD_INV_ITEM_ONHAND_REV_STG_T (
                                        RECORD_ID,
                                        BATCH_NUMBER,
                                        RECORD_STATUS,
                                        INTERFACE_LINE_ID,
                                        INTERFACE_HEADER_ID,
                                        ORGANIZATION_ID,
                                        PO_HEADER_ID,
                                        CURRENCY_CODE,
                                        AGENT_NAME,
                                        VENDOR_NAME,
                                        VENDOR_SITE_CODE,
                                        SHIP_TO_LOCATION,
                                        BILL_TO_LOCATION)
                             VALUES (XXD_INV_ITEM_ONHAND_REC_SEQ.NEXTVAL, lt_batch_id (ln_count), 'NEW', NULL, lx_interface_header_id, lt_po_stg_tab_type (cust_idx).ORGANIZATION_ID, PO_HEADERS_S.CURRVAL, v_currency_code, -- 'USD',--CURRENCY_CODE              ,
                                                                                                                                                                                                                             v_agent_name, --NULL,--AGENT_NAME                 ,
                                                                                                                                                                                                                                           v_vendor_name, --NULL,--VENDOR_NAME                ,
                                                                                                                                                                                                                                                          v_vendor_site, --NULL,--VENDOR_SITE_CODE           ,
                                                                                                                                                                                                                                                                         v_ship_to_location
                                     ,   --NULL,--SHIP_TO_LOCATION           ,
                                       v_bill_to_location --NULL--BILL_TO_LOCATION
                                                         );

                        COMMIT;
                    END IF;

                    BEGIN
                        SELECT PO_LINES_INTERFACE_S.NEXTVAL
                          INTO lx_interface_line_id
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            xxd_common_utils.record_error (
                                'PO',
                                gn_org_id,
                                'XXD Open Purchase Orders Conversion Program',
                                --  SQLCODE,
                                SQLERRM,
                                DBMS_UTILITY.format_error_backtrace,
                                --   DBMS_UTILITY.format_call_stack,
                                --   SYSDATE,
                                gn_user_id,
                                gn_conc_request_id,
                                'transfer_po_header_records',
                                NULL,
                                   SUBSTR (SQLERRM, 1, 150)
                                || ' Exception fetching group id in transfer_po_line_records procedure ');
                            log_records (
                                gc_debug_flag,
                                   SUBSTR (SQLERRM, 1, 150)
                                || ' Exception fetching group id in transfer_po_line_records procedure ');
                            RAISE ex_program_exception;
                    END;

                    log_records (
                        gc_debug_flag,
                        'lx_interface_line_id =>' || lx_interface_line_id);

                    ln_line_rec_cnt   := ln_line_rec_cnt + 1;
                    ----------------Collect PO line Records from stage table--------------
                    lt_po_line_type (ln_line_rec_cnt).INTERFACE_LINE_ID   :=
                        lx_interface_line_id;
                    lt_po_line_type (ln_line_rec_cnt).INTERFACE_HEADER_ID   :=
                        lx_interface_header_id;
                    lt_po_line_type (ln_line_rec_cnt).ORGANIZATION_ID   :=
                        lt_po_stg_tab_type (cust_idx).ORGANIZATION_ID;
                    lt_po_line_type (ln_line_rec_cnt).PO_HEADER_ID   :=
                        PO_HEADERS_S.CURRVAL;
                    lt_po_line_type (ln_line_rec_cnt).PO_LINE_ID   :=
                        PO_LINES_S.NEXTVAL;
                    lt_po_line_type (ln_line_rec_cnt).LINE_TYPE   :=
                        'Goods';            --rec_get_valid_rec.LINE_TYPE    ;
                    lt_po_line_type (ln_line_rec_cnt).ITEM   :=
                        lt_po_stg_tab_type (cust_idx).ITEM;
                    lt_po_line_type (ln_line_rec_cnt).ITEM_ID   :=
                        lt_po_stg_tab_type (cust_idx).ITEM_ID;
                    lt_po_line_type (ln_line_rec_cnt).QUANTITY   :=
                        lt_po_stg_tab_type (cust_idx).QUANTITY;
                    lt_po_line_type (ln_line_rec_cnt).UNIT_PRICE   :=
                        lt_po_stg_tab_type (cust_idx).UNIT_PRICE;
                    lt_po_line_type (ln_line_rec_cnt).NEED_BY_DATE   :=
                        lt_po_stg_tab_type (cust_idx).NEED_BY_DATE;
                    lt_po_line_type (ln_line_rec_cnt).PROMISED_DATE   :=
                        lt_po_stg_tab_type (cust_idx).PROMISED_DATE;
                    lt_po_line_type (ln_line_rec_cnt).SHIP_TO_ORGANIZATION_ID   :=
                        lt_po_stg_tab_type (cust_idx).SHIP_TO_ORGANIZATION_ID;
                    lt_po_line_type (ln_line_rec_cnt).LINE_ATTRIBUTE14   :=
                        lt_po_stg_tab_type (cust_idx).SUBINVENTORY;
                    lt_po_line_type (ln_line_rec_cnt).LINE_ATTRIBUTE15   :=
                        lt_po_stg_tab_type (cust_idx).new_locator_id;



                    UPDATE XXD_INV_ITEM_ONHAND_PO_STG_T
                       SET PO_HEADER_ID = PO_HEADERS_S.CURRVAL, RECORD_STATUS = gc_process_status
                     WHERE     1 = 1
                           --AND record_id =  lt_po_stg_tab_type(cust_idx).record_id;
                           AND ITEM_ID =
                               lt_po_stg_tab_type (cust_idx).ITEM_ID
                           AND TRUNC (NEED_BY_DATE) =
                               lt_po_stg_tab_type (cust_idx).NEED_BY_DATE
                           AND SUBINVENTORY =
                               lt_po_stg_tab_type (cust_idx).SUBINVENTORY
                           AND ORGANIZATION_ID =
                               lt_po_stg_tab_type (cust_idx).ORGANIZATION_ID
                           AND SHIP_TO_ORGANIZATION_ID =
                               lt_po_stg_tab_type (cust_idx).SHIP_TO_ORGANIZATION_ID
                           AND SUBINVENTORY =
                               lt_po_stg_tab_type (cust_idx).SUBINVENTORY;


                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Before insert into PO LINES INTERFACE Table :');

                    -------------------------------------------------------------------
                    -- do a bulk insert into the po_lines_interface table for the batch
                    ----------------------------------------------------------------
                    FORALL ln_cnt IN 1 .. lt_po_line_type.COUNT
                      SAVE EXCEPTIONS
                        INSERT INTO po_lines_interface
                             VALUES lt_po_line_type (ln_cnt);

                    ln_line_rec_cnt   :=
                        0;
                    lt_po_line_type.delete;
                END LOOP;

                COMMIT;
                EXIT WHEN c_get_valid_rec%NOTFOUND;
            END LOOP;

            CLOSE c_get_valid_rec;
        END LOOP;

        FOR rec IN lt_batch_id.FIRST .. lt_batch_id.LAST
        LOOP
            submit_po_request (p_batch_id        => lt_batch_id (rec),
                               p_org_id          => lt_org_id (rec),
                               p_submit_openpo   => lc_submit_openpo);
        END LOOP;
    EXCEPTION
        WHEN ex_program_Exception
        THEN
            ROLLBACK;
            x_ret_code   := gn_err_const;

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;
        WHEN ex_bulk_exceptions
        THEN
            ROLLBACK;
            l_bulk_errors   := SQL%BULK_EXCEPTIONS.COUNT;
            x_ret_code      := gn_err_const;

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;

            FOR l_errcnt IN 1 .. l_bulk_errors
            LOOP
                xxd_common_utils.record_error (
                    'PO',
                    gn_org_id,
                    'XXD Open Purchase Orders Conversion Program',
                    --  SQLCODE,
                    SQLERRM,
                    DBMS_UTILITY.format_error_backtrace,
                    --   DBMS_UTILITY.format_call_stack,
                    --   SYSDATE,
                    gn_user_id,
                    gn_conc_request_id,
                    'transfer_po_line_records',
                    NULL,
                       SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE)
                    || ' Exception in transfer_po_line_records procedure ');

                log_records (
                    gc_debug_flag,
                       SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE)
                    || ' Exception in transfer_po_line_records procedure 1');
            END LOOP;
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_ret_code   := gn_err_const;
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --  SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --   SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'transfer_po_line_records',
                NULL,
                   SUBSTR (SQLERRM, 1, 250)
                || ' Exception in transfer_po_line_records procedure');
            log_records (
                gc_debug_flag,
                   SUBSTR (SQLERRM, 1, 250)
                || ' Exception in transfer_po_line_records procedure 2');

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;
    END transfer_po_line_records;


    PROCEDURE transfer_po_ret_line_records (x_ret_code OUT VARCHAR2, p_operating_unit VARCHAR2, p_inventory_org VARCHAR2)
    /**********************************************************************************************
    *                                                                                             *
    * Procedure Name       :  transfer_po_line_records                                            *
    *                                                                                             *
    * Description          :  This procedure will populate the po_lines_interface program         *
    *                                                                                             *
    * Parameters         Type       Description                                                   *
    * ---------------    ----       ---------------------                                         *
    * x_ret_code         OUT        Return Code                                                   *
    * x_rec_count        OUT        No of records transferred to interface table                  *
    * x_int_run_id       OUT        Interface Run Id                                              *
    *                                                                                             *
    *                                                                                             *
    **********************************************************************************************/
    IS
        TYPE type_po_line_t IS TABLE OF po_lines_interface%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_po_line_type              type_po_line_t;

        TYPE type_po_header_t IS TABLE OF po_headers_interface%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_po_headre_type            type_po_header_t;


        ln_valid_rec_cnt             NUMBER := 0;
        ln_line_rec_cnt              NUMBER := 0;
        ln_count                     NUMBER := 0;
        ln_int_run_id                NUMBER;
        l_bulk_errors                NUMBER := 0;
        lx_interface_line_id         NUMBER := 0;
        lx_interface_header_id       NUMBER := 0;

        ln_organization_id           NUMBER := 0;
        ln_ship_to_organization_id   NUMBER := 0;

        lc_submit_openpo             VARCHAR2 (10) := 'N';
        v_agent_name                 VARCHAR2 (4000);
        v_vendor_name                VARCHAR2 (4000);
        v_vendor_site                VARCHAR2 (4000);
        v_currency_code              VARCHAR2 (10);
        v_ship_to_location           VARCHAR2 (4000);
        v_bill_to_location           VARCHAR2 (4000);
        v_chk_flag                   VARCHAR2 (1) := 'Y';
        v_inventory_org_id           NUMBER;
        v_organization_id            NUMBER;
        ex_bulk_exceptions           EXCEPTION;
        PRAGMA EXCEPTION_INIT (ex_bulk_exceptions, -24381);

        ex_program_exception         EXCEPTION;


        CURSOR c_iorg (c_operating_unit VARCHAR2, c_inventory_org VARCHAR2)
        IS
            SELECT ood.organization_id, ood.operating_unit
              FROM hr_operating_units hou, org_organization_definitions ood
             WHERE     HOU.ORGANIZATION_ID = ood.operating_unit
                   AND hou.name = NVL (c_operating_unit, hou.name)
                   AND ood.organization_code =
                       NVL (c_inventory_org, ood.organization_code);

        --------------------------------------------------------
        --Cursor to fetch the Return/REJ Subinventory valid records from staging table
        ----------------------------------------------------------
        CURSOR c_get_valid_rec IS
              SELECT ORGANIZATION_ID, ITEM, ITEM_ID,
                     SUM (QUANTITY) QUANTITY, UNIT_PRICE, TRUNC (NEED_BY_DATE) NEED_BY_DATE,
                     TRUNC (PROMISED_DATE) PROMISED_DATE, SHIP_TO_ORGANIZATION_ID, SUBINVENTORY,
                     new_locator_id
                --,locator
                FROM XXD_INV_ITEM_ONHAND_PO_STG_T XPOL
               WHERE     XPOL.record_status = gc_validate_status
                     AND RETURN_SUBINV_PO = 'Y'
                     AND ORGANIZATION_ID = v_organization_id
                     AND SHIP_TO_ORGANIZATION_ID =
                         NVL (v_inventory_org_id, SHIP_TO_ORGANIZATION_ID)
            GROUP BY ORGANIZATION_ID, SUBINVENTORY, ITEM_ID,
                     ITEM, NEW_LOCATOR_ID, SHIP_TO_ORGANIZATION_ID,
                     TRUNC (NEED_BY_DATE), TRUNC (PROMISED_DATE), UNIT_PRICE
            ORDER BY ORGANIZATION_ID, SHIP_TO_ORGANIZATION_ID, TRUNC (NEED_BY_DATE);

        TYPE type_po_stg_t IS TABLE OF c_get_valid_rec%ROWTYPE
            INDEX BY BINARY_INTEGER;


        lt_po_stg_tab_type           type_po_stg_t;


        TYPE organization_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        lt_org_id                    organization_table;
        ln_cnt                       NUMBER := 0;

        TYPE group_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        lt_batch_id                  group_table;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'AFTER Begin');
        x_ret_code   := gn_suc_const;
        log_records (gc_debug_flag,
                     'Start of transfer_po_return_line_records procedure');

        lt_po_line_type.DELETE;

        FOR i IN c_iorg (p_operating_unit, p_inventory_org)
        LOOP
            v_organization_id    := i.operating_unit;
            v_inventory_org_id   := i.organization_id;

            OPEN c_get_valid_rec;

            LOOP
                FETCH c_get_valid_rec
                    BULK COLLECT INTO lt_po_stg_tab_type
                    LIMIT 3000;

                --         SAVEPOINT INSERT_TABLE2;
                ln_valid_rec_cnt   := 0;

                FOR cust_idx IN 1 .. lt_po_stg_tab_type.COUNT
                LOOP
                    IF v_chk_flag = 'Y'
                    THEN
                        --FOR rec_get_rec IN c_get_rec(lt_po_stg_tab_type(cust_idx).ORGANIZATION_ID) LOOP


                        -------------------------------------------------------------------------------
                        --Query to fetch the Primary SHIP_TO_LOCATION AND BILL_TO_LOCATION Based on OU
                        -------------------------------------------------------------------------------
                        BEGIN
                            SELECT attribute1 ship_to_location
                              INTO v_ship_to_location
                              FROM fnd_lookup_values
                             WHERE     lookup_type =
                                       'XXD_INV_ONHAND_CONV_LOOKUP'
                                   AND lookup_code =
                                       TO_CHAR (
                                           lt_po_stg_tab_type (cust_idx).ORGANIZATION_ID)
                                   AND language = USERENV ('LANG');
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                v_ship_to_location   := NULL;
                                log_records (
                                    gc_debug_flag,
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception fetching ship to Location in transfer_records procedure ');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Exception fetching ship to Location in transfer_records procedure ');
                                RAISE ex_program_exception;
                        END;

                        BEGIN
                            SELECT attribute2 Bill_to_location
                              INTO v_bill_to_location
                              FROM fnd_lookup_values
                             WHERE     lookup_type =
                                       'XXD_INV_ONHAND_CONV_LOOKUP'
                                   AND lookup_code =
                                       TO_CHAR (
                                           lt_po_stg_tab_type (cust_idx).ORGANIZATION_ID)
                                   AND language = USERENV ('LANG');
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                v_bill_to_location   := NULL;
                                log_records (
                                    gc_debug_flag,
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception fetching Bill to Location in transfer_records procedure ');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Exception fetching Bill to Location in transfer_records procedure ');
                                RAISE ex_program_exception;
                        END;

                        -------------------------------------------------------------------------------
                        --Query to fetch the CURRENCY_CODE based on OU
                        -------------------------------------------------------------------------------
                        BEGIN
                            SELECT CUR.CURRENCY_CODE
                              INTO v_currency_code
                              FROM FINANCIALS_SYSTEM_PARAMS_ALL FSPA, GL_SETS_OF_BOOKS SOB, FND_CURRENCIES CUR
                             WHERE     FSPA.SET_OF_BOOKS_ID =
                                       SOB.SET_OF_BOOKS_ID
                                   AND CUR.CURRENCY_CODE = SOB.CURRENCY_CODE
                                   AND FSPA.ORG_ID =
                                       lt_po_stg_tab_type (cust_idx).ORGANIZATION_ID;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                v_currency_code   := NULL;
                                log_records (
                                    gc_debug_flag,
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception fetching Currency Code in transfer_records procedure ');
                        END;

                        -------------------------------------------------------------------------------
                        --Query to fetch the AGENT_NAME based on OU user login
                        -------------------------------------------------------------------------------
                        BEGIN
                            SELECT P.FULL_NAME Agent_name
                              INTO v_agent_name
                              FROM PER_PEOPLE_F P, PO_AGENTS PA, FND_USER fu
                             WHERE     PA.AGENT_ID = P.PERSON_ID
                                   AND p.PERSON_ID = fu.EMPLOYEE_ID
                                   AND fu.user_id =
                                       fnd_profile.VALUE ('USER_ID');
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                v_agent_name   := 'Stewart, Celene';
                                log_records (
                                    gc_debug_flag,
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception fetching Agent Name in transfer_records procedure .So default it to Stewart, Celene ');
                                fnd_file.put_line (fnd_file.LOG,
                                                   'Invalid Agent Name ');
                        END;

                        -------------------------------------------------------------------------------
                        --Query to fetch the VENDOR_NAME based on Lookup Value
                        -------------------------------------------------------------------------------
                        BEGIN
                            SELECT meaning
                              INTO v_vendor_name
                              FROM fnd_lookup_values
                             WHERE     lookup_type =
                                       'XXD_INV_ONHAND_CONV_LOOKUP'
                                   AND lookup_code = 'VENDOR_NAME'
                                   AND language = USERENV ('LANG');
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                v_vendor_name   := NULL;
                                log_records (
                                    gc_debug_flag,
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception fetching Vendor Name in transfer_records procedure ');
                                fnd_file.put_line (fnd_file.LOG,
                                                   'Invalid Vendor Name ');
                        END;

                        -------------------------------------------------------------------------------
                        --Query to fetch the VENDOR_SITE_CODE based on Lookup Value
                        -------------------------------------------------------------------------------
                        BEGIN
                            SELECT meaning
                              INTO v_vendor_site
                              FROM fnd_lookup_values
                             WHERE     lookup_type =
                                       'XXD_INV_ONHAND_CONV_LOOKUP'
                                   AND lookup_code = 'VENDOR_SITE'
                                   AND language = USERENV ('LANG');
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                v_vendor_site   := NULL;
                                log_records (
                                    gc_debug_flag,
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception fetching Vendor Site Name in transfer_records procedure ');
                                fnd_file.put_line (fnd_file.LOG,
                                                   'Invalid Vendor Site');
                        END;

                        --
                        v_chk_flag   := 'N';
                    --END LOOP;
                    END IF;

                    lt_po_headre_type.delete;
                    --   log_records (gc_debug_flag,'Row count :'||ln_valid_rec_cnt);

                    --        IF ln_organization_id <> lt_po_stg_tab_type(cust_idx).ORGANIZATION_ID
                    --        OR ln_ship_to_organization_id <> lt_po_stg_tab_type(cust_idx).SHIP_TO_ORGANIZATION_ID THEN
                    --
                    -- IF ln_organization_id <> lt_po_stg_tab_type(cust_idx).ORGANIZATION_ID  THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'ln_valid_rec_cnt :' || ln_valid_rec_cnt);

                    IF ln_valid_rec_cnt = 0
                    THEN
                        ln_count               := ln_count + 1;
                        ln_line_rec_cnt        := 0;
                        ln_valid_rec_cnt       := 1;  --ln_valid_rec_cnt + 1 ;
                        lt_po_line_type.delete;
                        ln_organization_id     :=
                            lt_po_stg_tab_type (cust_idx).ORGANIZATION_ID;
                        lt_org_id (ln_count)   := ln_organization_id;
                        lt_batch_id (ln_count)   :=
                            PO_CONTROL_GROUPS_S.NEXTVAL;

                        --END IF;
                        ln_ship_to_organization_id   :=
                            lt_po_stg_tab_type (cust_idx).SHIP_TO_ORGANIZATION_ID;
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'lt_org_id (ln_count)  :' || ln_organization_id);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'ln_valid_rec_cnt :' || ln_valid_rec_cnt);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'lt_batch_id (ln_count) :'
                            || lt_batch_id (ln_count));
                        log_records (
                            gc_debug_flag,
                               'lt_batch_id (ln_count) =>'
                            || lt_batch_id (ln_count));
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'userid : ' || fnd_profile.VALUE ('USER_ID'));

                        BEGIN
                            SELECT po_headers_interface_s.NEXTVAL
                              INTO lx_interface_header_id
                              FROM DUAL;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                xxd_common_utils.record_error (
                                    'PO',
                                    gn_org_id,
                                    'XXD Open Purchase Orders Conversion Program',
                                    --  SQLCODE,
                                    SQLERRM,
                                    DBMS_UTILITY.format_error_backtrace,
                                    --   DBMS_UTILITY.format_call_stack,
                                    --   SYSDATE,
                                    gn_user_id,
                                    gn_conc_request_id,
                                    'transfer_po_header_records',
                                    NULL,
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception fetching group id in transfer_records procedure ');
                                log_records (
                                    gc_debug_flag,
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception fetching group id in transfer_records procedure ');
                                RAISE ex_program_exception;
                        END;

                        log_records (
                            gc_debug_flag,
                               'INTERFACE_HEADER_ID =>'
                            || lx_interface_header_id);



                        ----------------Collect PO header Records from stage table--------------
                        lt_po_headre_type (ln_valid_rec_cnt).INTERFACE_HEADER_ID   :=
                            lx_interface_header_id; --rec_get_valid_rec.INTERFACE_HEADER_ID    ;
                        lt_po_headre_type (ln_valid_rec_cnt).BATCH_ID   :=
                            lt_batch_id (ln_count); --rec_get_valid_rec.BATCH_ID    ;
                        lt_po_headre_type (ln_valid_rec_cnt).ACTION   :=
                            'ORIGINAL';        --rec_get_valid_rec.ACTION    ;
                        lt_po_headre_type (ln_valid_rec_cnt).ORG_ID   :=
                            lt_po_stg_tab_type (cust_idx).ORGANIZATION_ID;
                        lt_po_headre_type (ln_valid_rec_cnt).DOCUMENT_TYPE_CODE   :=
                            'STANDARD'; --rec_get_valid_rec.DOCUMENT_SUBTYPE    ;
                        --            lt_po_headre_type(ln_valid_rec_cnt).DOCUMENT_NUM                            :=        rec_get_valid_rec.DOCUMENT_NUM    ;
                        lt_po_headre_type (ln_valid_rec_cnt).PO_HEADER_ID   :=
                            PO_HEADERS_S.NEXTVAL;

                        lt_po_headre_type (ln_valid_rec_cnt).CURRENCY_CODE   :=
                            v_currency_code; --'USD';--rec_get_valid_rec.CURRENCY_CODE    ;
                        lt_po_headre_type (ln_valid_rec_cnt).AGENT_NAME   :=
                            v_agent_name; --'Stewart, Celene';--rec_get_valid_rec.AGENT_NAME    ;
                        lt_po_headre_type (ln_valid_rec_cnt).VENDOR_NAME   :=
                            v_vendor_name; --'DURAMAS, S.A. DE C.V.';--rec_get_valid_rec.VENDOR_NAME    ;
                        lt_po_headre_type (ln_valid_rec_cnt).VENDOR_SITE_CODE   :=
                            v_vendor_site; --'DURAMAS';--rec_get_valid_rec.VENDOR_SITE_CODE    ;
                        lt_po_headre_type (ln_valid_rec_cnt).SHIP_TO_LOCATION   :=
                            v_ship_to_location; --'US - DC1 Ventura' ;--rec_get_valid_rec.SHIP_TO_LOCATION    ;
                        lt_po_headre_type (ln_valid_rec_cnt).BILL_TO_LOCATION   :=
                            v_bill_to_location; --'Deckers US, Goleta';--rec_get_valid_rec.BILL_TO_LOCATION    ;


                        -------------------------------------------------------------------
                        -- do a bulk insert into the po_headers_interface table for the batch
                        ----------------------------------------------------------------
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Before inserting PO HEADER INTERFACE TABLE :');

                        FORALL ln_cnt IN 1 .. lt_po_headre_type.COUNT
                          SAVE EXCEPTIONS
                            INSERT INTO po_headers_interface
                                 VALUES lt_po_headre_type (ln_cnt);

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'AFTER inserting PO Header Table :');

                        INSERT INTO XXD_INV_ITEM_ONHAND_REV_STG_T (
                                        RECORD_ID,
                                        BATCH_NUMBER,
                                        RECORD_STATUS,
                                        INTERFACE_LINE_ID,
                                        INTERFACE_HEADER_ID,
                                        ORGANIZATION_ID,
                                        PO_HEADER_ID,
                                        CURRENCY_CODE,
                                        AGENT_NAME,
                                        VENDOR_NAME,
                                        VENDOR_SITE_CODE,
                                        SHIP_TO_LOCATION,
                                        BILL_TO_LOCATION)
                             VALUES (XXD_INV_ITEM_ONHAND_REC_SEQ.NEXTVAL, lt_batch_id (ln_count), 'NEW', NULL, lx_interface_header_id, lt_po_stg_tab_type (cust_idx).ORGANIZATION_ID, PO_HEADERS_S.CURRVAL, v_currency_code, -- 'USD',--CURRENCY_CODE              ,
                                                                                                                                                                                                                             v_agent_name, --NULL,--AGENT_NAME                 ,
                                                                                                                                                                                                                                           v_vendor_name, --NULL,--VENDOR_NAME                ,
                                                                                                                                                                                                                                                          v_vendor_site, --NULL,--VENDOR_SITE_CODE           ,
                                                                                                                                                                                                                                                                         v_ship_to_location
                                     ,   --NULL,--SHIP_TO_LOCATION           ,
                                       v_bill_to_location --NULL--BILL_TO_LOCATION
                                                         );

                        COMMIT;
                    END IF;

                    BEGIN
                        SELECT PO_LINES_INTERFACE_S.NEXTVAL
                          INTO lx_interface_line_id
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            xxd_common_utils.record_error (
                                'PO',
                                gn_org_id,
                                'XXD Open Purchase Orders Conversion Program',
                                --  SQLCODE,
                                SQLERRM,
                                DBMS_UTILITY.format_error_backtrace,
                                --   DBMS_UTILITY.format_call_stack,
                                --   SYSDATE,
                                gn_user_id,
                                gn_conc_request_id,
                                'transfer_po_header_records',
                                NULL,
                                   SUBSTR (SQLERRM, 1, 150)
                                || ' Exception fetching group id in transfer_po_line_records procedure ');
                            log_records (
                                gc_debug_flag,
                                   SUBSTR (SQLERRM, 1, 150)
                                || ' Exception fetching group id in transfer_po_line_records procedure ');
                            RAISE ex_program_exception;
                    END;

                    log_records (
                        gc_debug_flag,
                        'lx_interface_line_id =>' || lx_interface_line_id);

                    ln_line_rec_cnt   := ln_line_rec_cnt + 1;
                    ----------------Collect PO line Records from stage table--------------
                    lt_po_line_type (ln_line_rec_cnt).INTERFACE_LINE_ID   :=
                        lx_interface_line_id;
                    lt_po_line_type (ln_line_rec_cnt).INTERFACE_HEADER_ID   :=
                        lx_interface_header_id;
                    lt_po_line_type (ln_line_rec_cnt).ORGANIZATION_ID   :=
                        lt_po_stg_tab_type (cust_idx).ORGANIZATION_ID;
                    lt_po_line_type (ln_line_rec_cnt).PO_HEADER_ID   :=
                        PO_HEADERS_S.CURRVAL;
                    lt_po_line_type (ln_line_rec_cnt).PO_LINE_ID   :=
                        PO_LINES_S.NEXTVAL;
                    lt_po_line_type (ln_line_rec_cnt).LINE_TYPE   :=
                        'Goods';            --rec_get_valid_rec.LINE_TYPE    ;
                    lt_po_line_type (ln_line_rec_cnt).ITEM   :=
                        lt_po_stg_tab_type (cust_idx).ITEM;
                    lt_po_line_type (ln_line_rec_cnt).ITEM_ID   :=
                        lt_po_stg_tab_type (cust_idx).ITEM_ID;
                    lt_po_line_type (ln_line_rec_cnt).QUANTITY   :=
                        lt_po_stg_tab_type (cust_idx).QUANTITY;
                    lt_po_line_type (ln_line_rec_cnt).UNIT_PRICE   :=
                        lt_po_stg_tab_type (cust_idx).UNIT_PRICE;
                    lt_po_line_type (ln_line_rec_cnt).NEED_BY_DATE   :=
                        lt_po_stg_tab_type (cust_idx).NEED_BY_DATE;
                    lt_po_line_type (ln_line_rec_cnt).PROMISED_DATE   :=
                        lt_po_stg_tab_type (cust_idx).PROMISED_DATE;
                    lt_po_line_type (ln_line_rec_cnt).SHIP_TO_ORGANIZATION_ID   :=
                        lt_po_stg_tab_type (cust_idx).SHIP_TO_ORGANIZATION_ID;
                    lt_po_line_type (ln_line_rec_cnt).LINE_ATTRIBUTE14   :=
                        lt_po_stg_tab_type (cust_idx).SUBINVENTORY;
                    lt_po_line_type (ln_line_rec_cnt).LINE_ATTRIBUTE15   :=
                        lt_po_stg_tab_type (cust_idx).new_locator_id;



                    UPDATE XXD_INV_ITEM_ONHAND_PO_STG_T
                       SET PO_HEADER_ID = PO_HEADERS_S.CURRVAL, RECORD_STATUS = gc_process_status
                     WHERE     1 = 1 --record_id =  lt_po_stg_tab_type(cust_idx).record_id;
                           AND ITEM_ID =
                               lt_po_stg_tab_type (cust_idx).ITEM_ID
                           --    AND trunc(NEED_BY_DATE)=lt_po_stg_tab_type(cust_idx).NEED_BY_DATE
                           AND SUBINVENTORY =
                               lt_po_stg_tab_type (cust_idx).SUBINVENTORY
                           AND ORGANIZATION_ID =
                               lt_po_stg_tab_type (cust_idx).ORGANIZATION_ID;


                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Before insert into PO LINES INTERFACE Table :');

                    -------------------------------------------------------------------
                    -- do a bulk insert into the po_lines_interface table for the batch
                    ----------------------------------------------------------------
                    FORALL ln_cnt IN 1 .. lt_po_line_type.COUNT
                      SAVE EXCEPTIONS
                        INSERT INTO po_lines_interface
                             VALUES lt_po_line_type (ln_cnt);

                    ln_line_rec_cnt   :=
                        0;
                    lt_po_line_type.delete;
                END LOOP;

                COMMIT;
                EXIT WHEN c_get_valid_rec%NOTFOUND;
            END LOOP;

            CLOSE c_get_valid_rec;
        END LOOP;

        FOR rec IN lt_batch_id.FIRST .. lt_batch_id.LAST
        LOOP
            submit_po_request (p_batch_id        => lt_batch_id (rec),
                               p_org_id          => lt_org_id (rec),
                               p_submit_openpo   => lc_submit_openpo);
        END LOOP;
    /*  FOR i in 572..591 LOOP
       fnd_file.put_line (fnd_file.LOG,'p_org_id=> lt_org_id(rec)'||95);
       fnd_file.put_line (fnd_file.LOG,'p_batch_id => lt_batch_id(rec)'|| i);
       fnd_file.put_line (fnd_file.LOG,'p_submit_openpo => lc_submit_openpo'|| lc_submit_openpo);
       submit_po_request(p_batch_id => i,p_org_id=> 95,p_submit_openpo => lc_submit_openpo);
      END LOOP;*/
    EXCEPTION
        WHEN ex_program_Exception
        THEN
            ROLLBACK;
            x_ret_code   := gn_err_const;

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;
        WHEN ex_bulk_exceptions
        THEN
            ROLLBACK;
            l_bulk_errors   := SQL%BULK_EXCEPTIONS.COUNT;
            x_ret_code      := gn_err_const;

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;

            FOR l_errcnt IN 1 .. l_bulk_errors
            LOOP
                xxd_common_utils.record_error (
                    'PO',
                    gn_org_id,
                    'XXD Open Purchase Orders Conversion Program',
                    --  SQLCODE,
                    SQLERRM,
                    DBMS_UTILITY.format_error_backtrace,
                    --   DBMS_UTILITY.format_call_stack,
                    --   SYSDATE,
                    gn_user_id,
                    gn_conc_request_id,
                    'transfer_po_line_records',
                    NULL,
                       SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE)
                    || ' Exception in transfer_po_line_records procedure ');

                log_records (
                    gc_debug_flag,
                       SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE)
                    || ' Exception in transfer_po_line_records procedure ');
            END LOOP;
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_ret_code   := gn_err_const;
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --  SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --   SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'transfer_po_line_records',
                NULL,
                   SUBSTR (SQLERRM, 1, 250)
                || ' Exception in transfer_po_line_records procedure');
            log_records (
                gc_debug_flag,
                   SUBSTR (SQLERRM, 1, 250)
                || ' Exception in transfer_po_line_records procedure');

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;
    END transfer_po_ret_line_records;

    PROCEDURE transfer_records (x_retcode OUT NUMBER, x_errbuf OUT VARCHAR2)
    /**********************************************************************************************
    *                                                                                             *
    * Procedure Name       :  transfer_records                                                    *
    *                                                                                             *
    * Description          :  This procedure will populate the gl_interface program               *
    *                                                                                             *
    * Parameters         Type       Description                                                   *
    * ---------------    ----       ---------------------                                         *
    * x_ret_code         OUT        Return Code                                                   *
    * x_rec_count        OUT        No of records transferred to interface table                  *
    * x_int_run_id       OUT        Interface Run Id                                              *
    *                                                                                             *
    * Change History                                                                              *
    * -----------------                                                                           *
    * Version       Date            Author                 Description                            *
    * -------       ----------      -----------------      ---------------------------            *
    *                                                                                             *
    **********************************************************************************************/
    IS
        TYPE type_ci_val_t IS TABLE OF XXD_INV_ITEM_ONHAND_PO_STG_T%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_ci_val_type           type_ci_val_t;

        ln_valid_rec_cnt         NUMBER := 0;
        ln_count                 NUMBER := 0;
        ln_int_run_id            NUMBER;
        l_bulk_errors            NUMBER := 0;
        v_TRANSACTION_DATE       DATE;
        v_SUBINVENTORY           VARCHAR2 (100);
        v_LOCATION_ID            NUMBER;

        ex_bulk_exceptions       EXCEPTION;

        v_inventory_item_id      NUMBER;
        v_inventory_org_id       NUMBER;
        v_rcv_transaction_date   DATE;
        PRAGMA EXCEPTION_INIT (ex_bulk_exceptions, -24381);

        ex_program_exception     EXCEPTION;

        /* ------------------------------------------------------------------------
         --Cursor to fetch the REJ/RETURNS Subinventory records from staging table
         --------------------------------------------------------------------------
          CURSOR c_trans_date_rec
          IS
          SELECT DISTINCT inventory_item_id,INVENTORY_ORG
           FROM XXD_INV_ITEM_ONHAND_QTY_STG_T rcvt
           WHERE 1=1
             AND record_status = gc_validate_status
             AND COST_TYPE = 'RECEIPT'
             AND SUBINVENTORY IN ('REJ','Rejects','Returns','RETURNS') ;*/

        --------------------------------------------------------
        --Cursor to fetch the valid records from staging table
        ----------------------------------------------------------
        CURSOR c_get_valid_rec IS
              SELECT NEW_OPERATING_NAME, NEW_OPERATING_UNIT_ID, NEW_INVENTORY_ORG_ID,
                     NEW_INVENTORY_ORG_NAME, ITEM_NUMBER, NEW_INVENTORY_ITEM_ID,
                     SUM (ONHAND_SPLIT_QTY) QUANTITY, TRUNC (RCV_TRANSACTION_DATE) RCV_TRANSACTION_DATE, COMPUTED_ITEM_COST,
                     SUBINVENTORY, LOCATOR, NEW_LOCATOR_ID,
                     NEW_INVENTORY_ORG_ID SHIP_TO_ORGANIZATION_ID
                FROM XXD_INV_ITEM_ONHAND_QTY_STG_T
               WHERE record_status = gc_validate_status
            --AND COST_TYPE = 'RECEIPT'
            GROUP BY NEW_OPERATING_NAME, NEW_OPERATING_UNIT_ID, NEW_INVENTORY_ORG_ID,
                     NEW_INVENTORY_ORG_NAME, ITEM_NUMBER, NEW_INVENTORY_ITEM_ID,
                     TRUNC (RCV_TRANSACTION_DATE), COMPUTED_ITEM_COST, SUBINVENTORY,
                     LOCATOR, NEW_LOCATOR_ID, NEW_INVENTORY_ORG_ID
            ORDER BY TRUNC (RCV_TRANSACTION_DATE);
    BEGIN
        x_retcode         := NULL;
        x_errbuf          := NULL;
        gc_code_pointer   := 'transfer_records';
        log_records (gc_debug_flag, 'Start of transfer_records procedure');

        SAVEPOINT INSERT_TABLE;



        lt_ci_val_type.DELETE;

        /*  FOR rec_trans_date_rec IN c_trans_date_rec
          LOOP
            v_inventory_item_id :=rec_trans_date_rec.INVENTORY_ITEM_ID;
            v_inventory_org_id :=rec_trans_date_rec.INVENTORY_ORG;
          BEGIN
            SELECT max(rcv_transaction_date)
              INTO  v_rcv_transaction_date
              FROM  XXD_INV_ITEM_ONHAND_QTY_STG_T
             WHERE  inventory_item_id=V_INVENTORY_ITEM_ID
               AND  INVENTORY_ORG= V_INVENTORY_ORG_ID
               AND  record_status= gc_validate_status
               AND SUBINVENTORY NOT IN ('REJ','Rejects','Returns','RETURNS') ;
         EXCEPTION
           WHEN NO_DATA_FOUND THEN
                   v_rcv_transaction_date:= NULL;
                    xxd_common_utils.record_error
                                      ('INV',
                                       gn_org_id,
                                       'Decker Inventory Item Onhand Conversion Program',
                                 --      SQLCODE,
                                       SQLERRM,
                                       DBMS_UTILITY.format_error_backtrace,
                                    --   DBMS_UTILITY.format_call_stack,
                                   --    SYSDATE,
                                      gn_user_id,
                                       gn_conc_request_id,
                                         'NO TRANSACTION FOUND FOR RETURN SUBINV'
                                       ,v_inventory_item_id
                                       ,'ITEM_ID '||v_inventory_item_id||'No other Transaction date exist for RETURN/REJ SUBINV ORG ID '||v_inventory_org_id||' '|| SQLERRM );
          WHEN OTHERS THEN
              v_rcv_transaction_date:= NULL;
          END;

            IF v_rcv_transaction_date IS NULL THEN
              BEGIN
                UPDATE XXD_INV_ITEM_ONHAND_QTY_STG_T
                   SET RECORD_STATUS = gc_error_status
                 WHERE inventory_item_id = v_inventory_item_id
                   AND inventory_org = v_inventory_org_id
                   AND SUBINVENTORY  IN ('REJ','Rejects','Returns','RETURNS');
              EXCEPTION
                WHEN OTHERS THEN
                log_records(gc_debug_flag,'Failed to update ERROR Records of REJ/RETURNS SUB INV with having null Transaction date');
                --dbms_output.put_line('Failed to update ERROR Records of REJ/RETURNS SUB INV with having null Transaction date');
              END;
            END IF;
           END LOOP;
           COMMIT;*/

        FOR rec_get_valid_rec IN c_get_valid_rec
        LOOP
            ln_count                                        := ln_count + 1;
            ln_valid_rec_cnt                                := c_get_valid_rec%ROWCOUNT;

            log_records (gc_debug_flag, 'Row count :' || ln_valid_rec_cnt);
            lt_ci_val_type (ln_count).RECORD_ID             :=
                XXD_INV_ITEM_ONHAND_REC_SEQ.NEXTVAL;
            lt_ci_val_type (ln_count).BATCH_NUMBER          := NULL;
            lt_ci_val_type (ln_count).RECORD_STATUS         := gc_validate_status;
            lt_ci_val_type (ln_count).INTERFACE_LINE_ID     := NULL;
            lt_ci_val_type (ln_count).INTERFACE_HEADER_ID   := NULL;
            lt_ci_val_type (ln_count).ORGANIZATION_ID       :=
                rec_get_valid_rec.NEW_OPERATING_UNIT_ID;
            lt_ci_val_type (ln_count).PO_HEADER_ID          := NULL;
            lt_ci_val_type (ln_count).LINE_TYPE             := NULL;
            lt_ci_val_type (ln_count).ITEM                  :=
                rec_get_valid_rec.ITEM_NUMBER;
            lt_ci_val_type (ln_count).ITEM_ID               :=
                rec_get_valid_rec.NEW_INVENTORY_ITEM_ID;
            lt_ci_val_type (ln_count).QUANTITY              :=
                rec_get_valid_rec.QUANTITY;
            lt_ci_val_type (ln_count).UNIT_PRICE            :=
                rec_get_valid_rec.COMPUTED_ITEM_COST;
            lt_ci_val_type (ln_count).SHIP_TO_ORGANIZATION_ID   :=
                rec_get_valid_rec.NEW_INVENTORY_ORG_ID;
            --lt_ci_val_type(ln_count).NEW_LOCATOR_ID              := rec_get_valid_rec.NEW_LOCATOR_ID;
            lt_ci_val_type (ln_count).SHIP_TO_ORGANIZATION_ID   :=
                rec_get_valid_rec.NEW_INVENTORY_ORG_ID;
            lt_ci_val_type (ln_count).LOCATOR               :=
                rec_get_valid_rec.LOCATOR;

            lt_ci_val_type (ln_count).SUBINVENTORY          :=
                rec_get_valid_rec.SUBINVENTORY;
            lt_ci_val_type (ln_count).NEW_LOCATOR_ID        :=
                rec_get_valid_rec.NEW_LOCATOR_ID;
            lt_ci_val_type (ln_count).NEED_BY_DATE          :=
                rec_get_valid_rec.RCV_TRANSACTION_DATE;
            lt_ci_val_type (ln_count).PROMISED_DATE         :=
                rec_get_valid_rec.RCV_TRANSACTION_DATE;

            IF rec_get_valid_rec.SUBINVENTORY IN ('REJ', 'Rejects', 'Returns',
                                                  'RETURNS')
            THEN
                lt_ci_val_type (ln_count).RETURN_SUBINV_PO   := 'Y';
            ELSE
                lt_ci_val_type (ln_count).RETURN_SUBINV_PO   := NULL;
            END IF;
        /*  dbms_output.put_line('RECORD_ID:' ||lt_ci_val_type(ln_count).RECORD_ID) ;
          dbms_output.put_line('BATCH_NUMBER:'||lt_ci_val_type(ln_count).BATCH_NUMBER);
          dbms_output.put_line('RECORD_STATUS:'||lt_ci_val_type(ln_count).RECORD_STATUS ) ;
          dbms_output.put_line('INTERFACE_LINE_ID:'||lt_ci_val_type(ln_count).INTERFACE_LINE_ID)      ;
          dbms_output.put_line('INTERFACE_HEADER_ID:'||lt_ci_val_type(ln_count).INTERFACE_HEADER_ID )     ;
          dbms_output.put_line('ORGANIZATION_ID:'||lt_ci_val_type(ln_count).ORGANIZATION_ID  )   ;
          dbms_output.put_line('PO_HEADER_ID:'||lt_ci_val_type(ln_count).PO_HEADER_ID);
          dbms_output.put_line('LINE_TYPE:'||lt_ci_val_type(ln_count).LINE_TYPE ) ;
          dbms_output.put_line('ITEM:'||lt_ci_val_type(ln_count).ITEM )     ;
          dbms_output.put_line('ITEM_ID:'||lt_ci_val_type(ln_count).ITEM_ID ) ;
          dbms_output.put_line('QUANTITY:'||lt_ci_val_type(ln_count).QUANTITY)   ;
          dbms_output.put_line('UNIT_PRICE:'||lt_ci_val_type(ln_count).UNIT_PRICE )   ;
          dbms_output.put_line('SHIP_TO_ORGANIZATION_ID:'||lt_ci_val_type(ln_count).SHIP_TO_ORGANIZATION_ID);
          dbms_output.put_line('SHIP_TO_ORGANIZATION_ID:'||lt_ci_val_type(ln_count).SHIP_TO_ORGANIZATION_ID);
          dbms_output.put_line('LOCATOR:'||lt_ci_val_type(ln_count).LOCATOR );
          dbms_output.put_line('SUBINVENTORY:'|| lt_ci_val_type(ln_count).SUBINVENTORY) ;
          dbms_output.put_line('NEW_LOCATOR_ID:'||lt_ci_val_type(ln_count).NEW_LOCATOR_ID);
          dbms_output.put_line('NEED_BY_DATE:'||lt_ci_val_type(ln_count).NEED_BY_DATE);
          dbms_output.put_line('PROMISED_DATE:'||lt_ci_val_type(ln_count).PROMISED_DATE);*/


        END LOOP;

        -------------------------------------------------------------------
        -- do a bulk insert into the XXD_INV_ITEM_ONHAND_PO_STG_T table for the batch
        ----------------------------------------------------------------
        FORALL ln_cnt IN 1 .. lt_ci_val_type.COUNT SAVE EXCEPTIONS
            INSERT INTO XXD_INV_ITEM_ONHAND_PO_STG_T
                 VALUES lt_ci_val_type (ln_cnt);

        -------------------------------------------------------------------
        --Update the records that have been transferred to XXD_INV_ITEM_ONHAND_PO_STG_T
        --as PROCESSED in staging table
        -------------------------------------------------------------------

        UPDATE XXD_INV_ITEM_ONHAND_QTY_STG_T XGPI
           SET XGPI.record_status   = gc_process_status
         WHERE XGPI.record_status = gc_validate_status;


        COMMIT;
    --        x_rec_count := ln_valid_rec_cnt;

    EXCEPTION
        WHEN ex_program_Exception
        THEN
            ROLLBACK TO INSERT_TABLE;
            fnd_file.put_line (fnd_file.LOG,
                               'Code Pointer: ' || gc_code_pointer);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Messgae: '
                || 'Unexpected error in Customer_main_proc '
                || SUBSTR (SQLERRM, 1, 250));
            fnd_file.put_line (fnd_file.LOG, '');
            x_retcode   := 2;
            x_errbuf    :=
                   'Error Message Customer_main_proc '
                || SUBSTR (SQLERRM, 1, 250);

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;
        WHEN ex_bulk_exceptions
        THEN
            ROLLBACK TO INSERT_TABLE;
            l_bulk_errors   := SQL%BULK_EXCEPTIONS.COUNT;
            fnd_file.put_line (fnd_file.LOG,
                               'Code Pointer: ' || gc_code_pointer);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Messgae: '
                || 'Unexpected error in Customer_main_proc '
                || SUBSTR (SQLERRM, 1, 250));
            fnd_file.put_line (fnd_file.LOG, '');
            x_retcode       := 2;
            x_errbuf        :=
                   'Error Message Customer_main_proc '
                || SUBSTR (SQLERRM, 1, 250);

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;

            FOR l_errcnt IN 1 .. l_bulk_errors
            LOOP
                NULL;
                log_records (
                    gc_debug_flag,
                       SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE)
                    || ' Exception in transfer_records procedure ');
            END LOOP;
        WHEN OTHERS
        THEN
            ROLLBACK TO INSERT_TABLE;
            fnd_file.put_line (fnd_file.LOG,
                               'Code Pointer: ' || gc_code_pointer);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Messgae: '
                || 'Unexpected error in Customer_main_proc '
                || SUBSTR (SQLERRM, 1, 250));
            fnd_file.put_line (fnd_file.LOG, '');
            x_retcode   := 2;
            x_errbuf    :=
                   'Error Message Customer_main_proc '
                || SUBSTR (SQLERRM, 1, 250);
            log_records (
                gc_debug_flag,
                   SUBSTR (SQLERRM, 1, 250)
                || ' Exception in transfer_records procedure');

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;
    END transfer_records;

    PROCEDURE Update_po_records (x_retcode OUT NUMBER, x_errbuf OUT VARCHAR2)
    /**********************************************************************************************
    *                                                                                             *
    * Procedure Name    :   Update_po_records                                                      *
    *                                                                                             *
    * Description          :  This procedure will populate the gl_interface program               *
    *                                                                                             *
    * Parameters         Type       Description                                                   *
    * ---------------    ----       ---------------------                                         *
    * x_ret_code         OUT        Return Code                                                   *
    * x_rec_count        OUT        No of records transferred to interface table                  *
    * x_int_run_id       OUT        Interface Run Id                                              *
    *                                                                                             *
    * Change History                                                                              *
    * -----------------                                                                           *
    * Version       Date            Author                 Description                            *
    * -------       ----------      -----------------      ---------------------------            *
    *                                                                                             *
    **********************************************************************************************/
    AS
        v_SUBINVENTORY           VARCHAR2 (100);
        v_LOCATION_ID            NUMBER;
        v_rcv_transaction_date   DATE;

        -- gc_validate_status VARCHAR2(50):= 'VALIDATED';
        ------------------------------------------------------------------------
        --Cursor to fetch the REJ/RETURNS Subinventory records from staging table
        --------------------------------------------------------------------------
        CURSOR c_trans_date_rec IS
            SELECT DISTINCT item_id, SUBINVENTORY, ship_to_organization_id
              FROM XXD_INV_ITEM_ONHAND_PO_STG_T rcvt
             WHERE     1 = 1
                   AND record_status = gc_validate_status
                   AND SUBINVENTORY IN ('REJ', 'Rejects', 'Returns',
                                        'RETURNS');
    BEGIN
        x_retcode         := NULL;
        x_errbuf          := NULL;
        gc_code_pointer   := 'PO_Update_records';
        log_records (gc_debug_flag, 'Start of PO_Update_records procedure');

        FOR rec_get_valid_rec IN c_trans_date_rec
        LOOP
            --dbms_output.put_line('IF CONDI SUBINVENTORY:'|| rec_get_valid_rec.SUBINVENTORY||'-'|| rec_get_valid_rec.NEW_INVENTORY_ITEM_ID||'-'||rec_get_valid_rec.NEW_INVENTORY_ORG_ID) ;
            BEGIN
                /* SELECT rcv_TRANSACTION_DATE --,SUBINVENTORY,NEW_LOCATOR_ID
                  INTO  v_rcv_transaction_date --,v_SUBINVENTORY,v_LOCATION_ID
                 FROM XXD_INV_ITEM_ONHAND_QTY_STG_T rcvt
                WHERE 1=1
                  AND record_status=gc_process_status
                  AND rcvt.rcv_transaction_date  IN (SELECT max(rcv_transaction_date)
                                                   FROM XXD_INV_ITEM_ONHAND_QTY_STG_T
                                                  WHERE  inventory_item_id = rcvt.INVENTORY_ITEM_ID
                                                    AND  INVENTORY_ORG = RCVT.INVENTORY_ORG
                                                    AND  new_inventory_item_id=rec_get_valid_rec.ITEM_ID
                                                    AND  NEW_INVENTORY_ORG_ID=rec_get_valid_rec.ship_to_organization_id
                                                    AND  record_status=gc_process_status
                                                    AND SUBINVENTORY NOT IN
                                                     ('REJ','Rejects','Returns','RETURNS') )
                 AND rownum=1 ;*/

                SELECT MAX (rcv_transaction_date)
                  INTO v_rcv_transaction_date
                  FROM XXD_INV_ITEM_ONHAND_QTY_STG_T
                 WHERE     1 = 1
                       AND new_inventory_item_id = rec_get_valid_rec.ITEM_ID
                       AND NEW_INVENTORY_ORG_ID =
                           rec_get_valid_rec.ship_to_organization_id
                       AND record_status = gc_process_status
                       AND SUBINVENTORY NOT IN ('REJ', 'Rejects', 'Returns',
                                                'RETURNS');
            EXCEPTION
                WHEN OTHERS
                THEN
                    log_records (
                        gc_debug_flag,
                           'ERROR WHILE FETCHING TRANSACTION DATE FOR RETURN/REJ SUBINV:'
                        || 'Item ID:'
                        || rec_get_valid_rec.ITEM_ID
                        || 'Organization ID:'
                        || rec_get_valid_rec.ship_to_organization_id
                        || SQLERRM);
                    --dbms_output.put_line('ERROR WHILE FETCHING TRANSACTION DATE FOR RETURN/REJ SUBINV:'||'Item ID:' ||rec_get_valid_rec.ITEM_ID||'Organization ID:'||rec_get_valid_rec.ship_to_organization_id||SQLERRM);
                    EXIT;
            END;

            BEGIN
                UPDATE XXD_INV_ITEM_ONHAND_PO_STG_T
                   SET need_by_date = v_rcv_transaction_date, promised_date = v_rcv_transaction_date--,SUBINVENTORY= v_SUBINVENTORY
                                                                                                    --,new_locator_id=v_LOCATION_ID
                                                                                                    , RETURN_SUBINV_PO = 'Y'
                 WHERE     item_id = rec_get_valid_rec.ITEM_ID
                       AND ship_to_organization_id =
                           rec_get_valid_rec.ship_to_organization_id
                       AND SUBINVENTORY IN ('REJ', 'Rejects', 'Returns',
                                            'RETURNS');
            EXCEPTION
                WHEN OTHERS
                THEN
                    log_records (
                        gc_debug_flag,
                        'Failed to update ERROR Records of REJ/RETURNS SUB INV with having null Transaction date');
            --dbms_output.put_line('Failed to update ERROR Records of REJ/RETURNS SUB INV with having  Transaction date'||SQLERRM);
            END;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                gc_debug_flag,
                'Failed to update ERROR Records of REJ/RETURNS SUB INV with having null Transaction date');
            fnd_file.put_line (fnd_file.LOG,
                               'Code Pointer: ' || gc_code_pointer);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Messgae: '
                || 'Unexpected error in Update_po_records_proc '
                || SUBSTR (SQLERRM, 1, 250));
            fnd_file.put_line (fnd_file.LOG, '');
            x_retcode   := 2;
            x_errbuf    :=
                   'Error Message Update_po_records_proc '
                || SUBSTR (SQLERRM, 1, 250);
    --dbms_output.put_line('In Final exception '||SQLERRM);
    END Update_po_records;


    PROCEDURE transfer_receipt_records (x_retcode OUT NUMBER, x_errbuf OUT VARCHAR2, p_po_header_id IN VARCHAR2
                                        , p_org_id IN NUMBER, P_TRANSACTION_DATE IN VARCHAR2, --RCV_TRANSACTIONS_INTERFACE.TRANSACTION_DATE%type,
                                                                                              x_group_id OUT NUMBER)
    /**********************************************************************************************
    *                                                                                             *
    * Procedure Name       :  transfer_records                                                    *
    *                                                                                             *
    * Description          :  This procedure will create receipts for PO's                        *
    *                                                                                             *
    * Parameters         Type       Description                                                   *
    * ---------------    ----       ---------------------                                         *
    * x_ret_code         OUT        Return Code                                                   *
    * x_rec_count        OUT        No of records transferred to interface table                  *
    * x_int_run_id       OUT        Interface Run Id                                              *
    *                                                                                             *
    * Change History                                                                              *
    * -----------------                                                                           *
    * Version       Date            Author                 Description                            *
    * -------       ----------      -----------------      ---------------------------            *
    *                                                                                             *
    **********************************************************************************************/
    IS
        X_USER_ID             NUMBER;
        X_PO_HEADER_ID        NUMBER;
        X_VENDOR_ID           NUMBER;
        X_LINE_NUM            NUMBER;
        X_INCLUDE_CLOSED_PO   VARCHAR2 (20) := 'N';

        TYPE group_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_group_id            group_table;
        ln_cnt                NUMBER := 0;
        ln_grp_cnt            NUMBER := 0;
        lc_submit_openpo      VARCHAR2 (10) := 'N';
        ld_need_by_date       DATE := SYSDATE + 10;
    BEGIN
        gc_code_pointer   := '***ezROI RCV API Insert Script***';

        --   SELECT USER_ID
        --     INTO X_USER_ID
        --     FROM FND_USER
        --    WHERE USER_NAME = UPPER ('PVADREVU001');

        --X_USER_ID :=  FND_GLOBAL.user_id;

        --   SELECT fpov.PROFILE_OPTION_VALUE
        --     INTO X_INCLUDE_CLOSED_PO
        --     FROM FND_PROFILE_OPTIONS fpo, FND_PROFILE_OPTION_VALUES fpov
        --    WHERE     fpov.PROFILE_OPTION_ID = fpo.PROFILE_OPTION_ID
        --          AND fpov.APPLICATION_ID = fpo.APPLICATION_ID
        --          AND fpov.LEVEL_ID = '10001'                                  -- Site
        --          --and fpov.LEVEL_ID = '10002' -- Application
        --          --and fpov.LEVEL_ID = '10003' -- Responsibility
        --          --and fpov.LEVEL_ID = '10004' -- User
        --          AND fpov.PROFILE_OPTION_VALUE IS NOT NULL
        --          AND fpo.PROFILE_OPTION_NAME = 'RCV_CLOSED_PO_DEFAULT_OPTION'; -- Profile 'RCV: Default Include Closed PO Option'

        log_records (
            gc_debug_flag,
            'p_po_header_id: ' || p_po_header_id || ' p_org_id: ' || p_org_id);

        log_records (
            'Y',
               'p_po_header_id: '
            || p_po_header_id
            || ' P_TRANSACTION_DATE: '
            --            || to_date(to_char(P_TRANSACTION_DATE,'YYYY/MM/DD HH:MI:SS'),'DD-MON-YYYY')
            || TO_CHAR (
                   TO_DATE (P_TRANSACTION_DATE, 'YYYY/MM/DD HH24:MI:SS'),
                   'DD-MON-YY')
            || 'sysdate'
            || SYSDATE);

        SELECT PO_HEADER_ID, VENDOR_ID, CREATED_BY
          INTO X_PO_HEADER_ID, X_VENDOR_ID, X_USER_ID
          FROM PO_HEADERS_ALL
         WHERE po_header_id = p_po_header_id AND ORG_ID = p_org_id;

        DECLARE
            CURSOR PO_DETAIL IS
                  SELECT PH.PO_HEADER_ID,                  -- RTI.PO_HEADER_ID
                                          PH.ORG_ID, PL.PO_LINE_ID -- RTI.PO_LINE_ID
                                                                  ,
                         PLL.LINE_LOCATION_ID          -- RTI.LINE_LOCATION_ID
                                             , POD.PO_DISTRIBUTION_ID -- RTI.PO_DISTRIBUTION_ID
                                                                     , PLL.UNIT_MEAS_LOOKUP_CODE -- RTI.UNIT_OF_MEASURE
                                                                                                ,
                         PLL.SHIP_TO_ORGANIZATION_ID -- RTI.TO_ORGANIZATION_ID
                                                    --,PLL.QUANTITY QUANTITY_ORDERED -- RTI.QUANTITY
                                                    , POD.QUANTITY_ORDERED QUANTITY_ORDERED -- RTI.QUANTITY
                                                                                           , PLL.SHIP_TO_LOCATION_ID -- RTI.SHIP_TO_LOCATION_ID
                                                                                                                    ,
                         NVL (PLL.PRICE_OVERRIDE, PL.UNIT_PRICE) UNIT_PRICE -- RTI.PO_UNIT_PRICE
                                                                           , PL.CATEGORY_ID -- RTI.CATEGORY_ID
                                                                                           , NVL (PLL.DESCRIPTION, PL.ITEM_DESCRIPTION) ITEM_DESCRIPTION -- RTI.ITEM_DESCRIPTION
                                                                                                                                                        ,
                         PL.ITEM_ID                             -- RTI.ITEM_ID
                                   , PH.CURRENCY_CODE     -- RTI.CURRENCY_CODE
                                                     , PH.RATE_TYPE -- RTI.CURRENCY_CONVERSION_TYPE
                                                                   ,
                         POD.RATE              -- RTI.CURRENCY_CONVERSION_RATE
                                 , POD.RATE_DATE -- RTI.CURRENCY_CONVERSION_DATE
                                                , POD.REQ_DISTRIBUTION_ID -- RTI.REQ_DISTRIBUTION_ID
                                                                         ,
                         POD.DELIVER_TO_LOCATION_ID -- RTI.DELIVER_TO_LOCATION_ID
                                                   , POD.DELIVER_TO_PERSON_ID -- RTI.DELIVER_TO_PERSON_ID
                                                                             , POD.DESTINATION_TYPE_CODE -- RTI.DESTINATION_TYPE_CODE
                                                                                                        ,
                         POD.DESTINATION_SUBINVENTORY      -- RTI.SUBINVENTORY
                                                     , POD.WIP_ENTITY_ID -- RTI.WIP_ENTITY_ID
                                                                        , POD.WIP_OPERATION_SEQ_NUM -- RTI.WIP_OPERATION_SEQ_NUM
                                                                                                   ,
                         POD.WIP_RESOURCE_SEQ_NUM  -- RTI.WIP_RESOURCE_SEQ_NUM
                                                 , POD.WIP_REPETITIVE_SCHEDULE_ID -- RTI.WIP_REPETITIVE_SCHEDULE_ID
                                                                                 , POD.WIP_LINE_ID -- RTI.WIP_LINE_ID
                                                                                                  ,
                         POD.BOM_RESOURCE_ID            -- RTI.BOM_RESOURCE_ID
                                            , POD.USSGL_TRANSACTION_CODE -- RTI.USSGL_TRANSACTION_CODE
                                                                        , NVL (PLL.PROMISED_DATE, PLL.NEED_BY_DATE) PROMISED_DATE -- RTI.EXPECTED_RECEIPT_DATE
                                                                                                                                 ,
                         PLL.UNIT_OF_MEASURE_CLASS               -- no RTI Col
                                                  , PLL.QUANTITY_SHIPPED -- no RTI Col
                                                                        , PLL.RECEIPT_DAYS_EXCEPTION_CODE -- no RTI col
                                                                                                         ,
                         PLL.QTY_RCV_TOLERANCE                   -- no RTI col
                                              , PLL.QTY_RCV_EXCEPTION_CODE -- no RTI col
                                                                          , PLL.DAYS_EARLY_RECEIPT_ALLOWED -- no RTI col
                                                                                                          ,
                         PLL.DAYS_LATE_RECEIPT_ALLOWED           -- no RTI col
                                                      , POD.CODE_COMBINATION_ID -- no RTI col
                                                                               , NVL (PLL.ENFORCE_SHIP_TO_LOCATION_CODE, 'NONE') ENFORCE_SHIP_TO_LOCATION_CODE -- no RTI col
                                                                                                                                                              ,
                         PLL.MATCH_OPTION, PL.LINE_NUM, PLL.SHIPMENT_NUM,
                         POD.DESTINATION_ORGANIZATION_ID, TO_NUMBER (NULL) SHIPMENT_LINE_ID, NVL (PL.attribute14, 'RECEIVING') SUBINVENTORY,
                         PL.attribute15 LOCATOR_ID
                    FROM PO_DISTRIBUTIONS_ALL POD, PO_LINE_LOCATIONS_ALL PLL, PO_LINES_ALL PL,
                         PO_HEADERS_ALL PH
                   WHERE     PH.PO_HEADER_ID = X_PO_HEADER_ID
                         AND PL.PO_HEADER_ID = PH.PO_HEADER_ID
                         AND PLL.PO_LINE_ID = PL.PO_LINE_ID
                         AND POD.LINE_LOCATION_ID = PLL.LINE_LOCATION_ID
                         AND NVL (PLL.APPROVED_FLAG, 'N') = 'Y'
                         AND NVL (PLL.CANCEL_FLAG, 'N') = 'N'
                         AND ((NVL (X_INCLUDE_CLOSED_PO, 'N') = 'Y' AND NVL (PLL.CLOSED_CODE, 'OPEN') <> 'FINALLY CLOSED') OR (NVL (X_INCLUDE_CLOSED_PO, 'N') = 'N' AND (NVL (PLL.CLOSED_CODE, 'OPEN') NOT IN ('FINALLY CLOSED', 'CLOSED', 'CLOSED FOR RECEIVING'))))
                         AND PLL.SHIPMENT_TYPE IN ('STANDARD', 'BLANKET', 'SCHEDULED',
                                                   'PREPAYMENT')
                ORDER BY NVL (PLL.PROMISED_DATE, PLL.NEED_BY_DATE);
        BEGIN
            ln_cnt   := 0;

            FOR RTICURSOR IN PO_DETAIL
            LOOP
                log_records (gc_debug_flag, 'RTICURSOR LOOP ');
                ln_cnt   := ln_cnt + 1;

                IF TRUNC (RTICURSOR.PROMISED_DATE) <> TRUNC (ld_need_by_date)
                THEN
                    ld_need_by_date   := TRUNC (RTICURSOR.PROMISED_DATE);

                    IF ln_cnt >= 2500 OR ln_cnt = 1
                    THEN
                        ln_grp_cnt                := ln_grp_cnt + 1;

                        SELECT RCV_INTERFACE_GROUPS_S.NEXTVAL
                          INTO x_group_id
                          FROM DUAL;

                        l_group_id (ln_grp_cnt)   := x_group_id;
                        ln_cnt                    := 1;
                    END IF;

                    log_records (
                        gc_debug_flag,
                        ' l_group_id(ln_cnt)  => ' || l_group_id (ln_grp_cnt));

                    INSERT INTO RCV_HEADERS_INTERFACE (
                                    HEADER_INTERFACE_ID,
                                    GROUP_ID,
                                    PROCESSING_STATUS_CODE,
                                    RECEIPT_SOURCE_CODE,
                                    TRANSACTION_TYPE,
                                    LAST_UPDATE_DATE,
                                    LAST_UPDATED_BY,
                                    LAST_UPDATE_LOGIN,
                                    VENDOR_ID,
                                    EXPECTED_RECEIPT_DATE,
                                    VALIDATION_FLAG,
                                    ATTRIBUTE15,
                                    SHIP_TO_ORGANIZATION_ID,
                                    ORG_ID)
                        SELECT RCV_HEADERS_INTERFACE_S.NEXTVAL, x_group_id, --RCV_INTERFACE_GROUPS_S.NEXTVAL,
                                                                            'PENDING',
                               'VENDOR', 'NEW', SYSDATE,
                               X_USER_ID, 0, X_VENDOR_ID,
                               SYSDATE, 'Y', TO_CHAR (RTICURSOR.PROMISED_DATE, 'DD-MON-YYYY'),
                               RTICURSOR.SHIP_TO_ORGANIZATION_ID, RTICURSOR.org_id
                          FROM DUAL;
                END IF;

                --      FOR RTICURSOR IN PO_DETAIL
                --      LOOP
                INSERT INTO RCV_TRANSACTIONS_INTERFACE (
                                INTERFACE_TRANSACTION_ID,
                                GROUP_ID,
                                LAST_UPDATE_DATE,
                                LAST_UPDATED_BY,
                                CREATION_DATE,
                                CREATED_BY,
                                LAST_UPDATE_LOGIN,
                                TRANSACTION_TYPE,
                                TRANSACTION_DATE,
                                PROCESSING_STATUS_CODE,
                                PROCESSING_MODE_CODE,
                                TRANSACTION_STATUS_CODE,
                                EXPECTED_RECEIPT_DATE -- NVL(PLL.PROMISED_DATE, PLL.NEED_BY_DATE) PROMISED_DATE
                                                     ,
                                PO_HEADER_ID                -- PH.PO_HEADER_ID
                                            ,
                                PO_LINE_ID                   --  PL.PO_LINE_ID
                                          ,
                                PO_LINE_LOCATION_ID -- PLL.PO_LINE_LOCATION_ID
                                                   ,
                                PO_DISTRIBUTION_ID   -- POD.PO_DISTRIBUTION_ID
                                                  ,
                                UNIT_OF_MEASURE   -- PLL.UNIT_MEAS_LOOKUP_CODE
                                               ,
                                TO_ORGANIZATION_ID -- PLL.SHIP_TO_ORGANIZATION_ID
                                                  ,
                                QUANTITY     --  PLL.QUANTITY QUANTITY_ORDERED
                                        ,
                                QUANTITY_SHIPPED       -- PLL.QUANTITY_SHIPPED
                                                ,
                                SHIP_TO_LOCATION_ID -- PLL.SHIP_TO_LOCATION_ID
                                                   ,
                                PO_UNIT_PRICE --  NVL(PLL.PRICE_OVERRIDE, PL.UNIT_PRICE) UNIT_PRICE
                                             ,
                                CATEGORY_ID                  -- PL.CATEGORY_ID
                                           ,
                                ITEM_DESCRIPTION -- NVL(PLL.DESCRIPTION, PL.ITEM_DESCRIPTION) ITEM_DESCRIPTION
                                                ,
                                ITEM_ID                          -- PL.ITEM_ID
                                       ,
                                CURRENCY_CODE              -- PH.CURRENCY_CODE
                                             ,
                                CURRENCY_CONVERSION_TYPE       -- PH.RATE_TYPE
                                                        ,
                                CURRENCY_CONVERSION_RATE           -- POD.RATE
                                                        ,
                                CURRENCY_CONVERSION_DATE      -- POD.RATE_DATE
                                                        ,
                                REQ_DISTRIBUTION_ID -- POD.REQ_DISTRIBUTION_ID
                                                   ,
                                DELIVER_TO_LOCATION_ID -- POD.DELIVER_TO_LOCATION_ID
                                                      ,
                                DELIVER_TO_PERSON_ID -- POD.DELIVER_TO_PERSON_ID
                                                    ,
                                DESTINATION_TYPE_CODE -- POD.DESTINATION_TYPE_CODE
                                                     ,
                                SUBINVENTORY   -- POD.DESTINATION_SUBINVENTORY
                                            ,
                                LOCATOR_ID,
                                WIP_ENTITY_ID             -- POD.WIP_ENTITY_ID
                                             ,
                                WIP_OPERATION_SEQ_NUM -- POD.WIP_OPERATION_SEQ_NUM
                                                     ,
                                WIP_RESOURCE_SEQ_NUM -- POD.WIP_RESOURCE_SEQ_NUM
                                                    ,
                                WIP_REPETITIVE_SCHEDULE_ID -- POD.WIP_REPETITIVE_SCHEDULE_ID
                                                          ,
                                WIP_LINE_ID                 -- POD.WIP_LINE_ID
                                           ,
                                BOM_RESOURCE_ID         -- POD.BOM_RESOURCE_ID
                                               ,
                                USSGL_TRANSACTION_CODE -- POD.USSGL_TRANSACTION_CODE
                                                      ,
                                SHIPMENT_LINE_ID -- TO_NUMBER(NULL) SHIPMENT_LINE_ID
                                                ,
                                HEADER_INTERFACE_ID,
                                VALIDATION_FLAG,
                                ATTRIBUTE15,
                                ORG_ID)
                    SELECT RCV_TRANSACTIONS_INTERFACE_S.NEXTVAL -- INTERFACE_TRANSACTION_ID
                                                               , x_group_id -- GROUP_ID
                                                                           , SYSDATE -- LAST_UPDATE_DATE
                                                                                    ,
                           X_USER_ID                        -- LAST_UPDATED_BY
                                    , SYSDATE                 -- CREATION_DATE
                                             , X_USER_ID         -- CREATED_BY
                                                        ,
                           0                              -- LAST_UPDATE_LOGIN
                            , 'RECEIVE'                    -- TRANSACTION_TYPE
                                       , TO_CHAR (TO_DATE (P_TRANSACTION_DATE, 'YYYY/MM/DD HH24:MI:SS'), 'DD-MON-YY') -- TRANSACTION_DATE
                                                                                                                     ,
                           'PENDING'                 -- PROCESSING_STATUS_CODE
                                    , 'BATCH'          -- PROCESSING_MODE_CODE
                                             , 'PENDING' -- TRANSACTION_STATUS_CODE
                                                        ,
                           RTICURSOR.PROMISED_DATE -- EXPECTED_RECEIPT_DATE  -- NVL(PLL.PROMISED_DATE, PLL.NEED_BY_DATE) PROMISED_DATE
                                                  , RTICURSOR.PO_HEADER_ID -- PO_HEADER_ID
                                                                          , RTICURSOR.PO_LINE_ID -- PO_LINE_ID
                                                                                                ,
                           RTICURSOR.LINE_LOCATION_ID      -- LINE_LOCATION_ID
                                                     , RTICURSOR.PO_DISTRIBUTION_ID -- PO_DISTRIBUTION_ID
                                                                                   , RTICURSOR.UNIT_MEAS_LOOKUP_CODE -- UNIT_OF_MEASURE  -- PLL.UNIT_MEAS_LOOKUP_CODE
                                                                                                                    ,
                           RTICURSOR.SHIP_TO_ORGANIZATION_ID -- TO_ORGANIZATION_ID  -- PLL.SHIP_TO_ORGANIZATION_ID
                                                            , RTICURSOR.QUANTITY_ORDERED -- QUANTITY --  PLL.QUANTITY QUANTITY_ORDERED
                                                                                        , RTICURSOR.QUANTITY_SHIPPED -- QUANTITY_SHIPPED  -- PLL.QUANTITY_SHIPPED
                                                                                                                    ,
                           RTICURSOR.SHIP_TO_LOCATION_ID --SHIP_TO_LOCATION_ID  -- PLL.SHIP_TO_LOCATION_ID
                                                        , RTICURSOR.UNIT_PRICE -- PO_UNIT_PRICE --  NVL(PLL.PRICE_OVERRIDE, PL.UNIT_PRICE) UNIT_PRICE
                                                                              , RTICURSOR.CATEGORY_ID -- CATEGORY_ID  -- PL.CATEGORY_ID
                                                                                                     ,
                           RTICURSOR.ITEM_DESCRIPTION -- ITEM_DESCRIPTION  -- NVL(PLL.DESCRIPTION, PL.ITEM_DESCRIPTION) ITEM_DESCRIPTION
                                                     , RTICURSOR.ITEM_ID -- ITEM_ID  -- PL.ITEM_ID
                                                                        , RTICURSOR.CURRENCY_CODE -- CURRENCY_CODE -- PH.CURRENCY_CODE
                                                                                                 ,
                           RTICURSOR.RATE_TYPE -- CURRENCY_CONVERSION_TYPE  -- PH.RATE_TYPE
                                              , RTICURSOR.RATE -- CURRENCY_CONVERSION_RATE -- POD.RATE
                                                              , RTICURSOR.RATE_DATE -- CURRENCY_CONVERSION_DATE  -- POD.RATE_DATE
                                                                                   ,
                           RTICURSOR.REQ_DISTRIBUTION_ID -- REQ_DISTRIBUTION_ID  -- POD.REQ_DISTRIBUTION_ID
                                                        , RTICURSOR.DELIVER_TO_LOCATION_ID -- DELIVER_TO_LOCATION_ID  -- POD.DELIVER_TO_LOCATION_ID
                                                                                          , RTICURSOR.DELIVER_TO_PERSON_ID -- DELIVER_TO_PERSON_ID  -- POD.DELIVER_TO_PERSON_ID
                                                                                                                          ,
                           RTICURSOR.DESTINATION_TYPE_CODE -- DESTINATION_TYPE_CODE  -- POD.DESTINATION_TYPE_CODE
                                                          , RTICURSOR.SUBINVENTORY --RTICURSOR.DESTINATION_SUBINVENTORY -- SUBINVENTORY  -- POD.DESTINATION_SUBINVENTORY
                                                                                  , RTICURSOR.LOCATOR_ID, --locator id
                           RTICURSOR.WIP_ENTITY_ID -- WIP_ENTITY_ID  -- POD.WIP_ENTITY_ID
                                                  , RTICURSOR.WIP_OPERATION_SEQ_NUM -- WIP_OPERATION_SEQ_NUM  -- POD.WIP_OPERATION_SEQ_NUM
                                                                                   , RTICURSOR.WIP_RESOURCE_SEQ_NUM -- WIP_RESOURCE_SEQ_NUM  -- POD.WIP_RESOURCE_SEQ_NUM
                                                                                                                   ,
                           RTICURSOR.WIP_REPETITIVE_SCHEDULE_ID -- WIP_REPETITIVE_SCHEDULE_ID  -- POD.WIP_REPETITIVE_SCHEDULE_ID
                                                               , RTICURSOR.WIP_LINE_ID -- WIP_LINE_ID  -- POD.WIP_LINE_ID
                                                                                      , RTICURSOR.BOM_RESOURCE_ID -- BOM_RESOURCE_ID  -- POD.BOM_RESOURCE_ID
                                                                                                                 ,
                           RTICURSOR.USSGL_TRANSACTION_CODE -- USSGL_TRANSACTION_CODE  -- POD.USSGL_TRANSACTION_CODE
                                                           , RTICURSOR.SHIPMENT_LINE_ID -- SHIPMENT_LINE_ID  -- TO_NUMBER(NULL) SHIPMENT_LINE_ID
                                                                                       , RCV_HEADERS_INTERFACE_S.CURRVAL,
                           'Y', TO_CHAR (RTICURSOR.PROMISED_DATE, 'DD-MON-YYYY'), RTICURSOR.org_id
                      FROM DUAL;

                log_records (
                    gc_debug_flag,
                       'PO line: '
                    || RTICURSOR.LINE_NUM
                    || ' Shipment: '
                    || RTICURSOR.SHIPMENT_NUM
                    || ' has been inserted into ROI.');
            END LOOP;

            log_records (gc_debug_flag, '*** ezROI COMPLETE - End ***');

            UPDATE XXD_INV_ITEM_ONHAND_REV_STG_T
               SET record_status   = gc_process_status
             WHERE po_header_id = p_po_header_id;
        END;

        COMMIT;

        FOR rec IN l_group_id.FIRST .. l_group_id.LAST
        LOOP
            submit_rcv_request (p_batch_id      => l_group_id (rec),
                                p_org_id        => p_org_id,
                                p_submit_flag   => lc_submit_openpo);
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            fnd_file.put_line (fnd_file.LOG,
                               'Code Pointer: ' || gc_code_pointer);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Messgae: '
                || 'Unexpected error in transfer_receipt_records '
                || SUBSTR (SQLERRM, 1, 250));
            fnd_file.put_line (fnd_file.LOG, '');
            x_retcode   := 2;
            x_errbuf    :=
                   'Error Message transfer_receipt_records '
                || SUBSTR (SQLERRM, 1, 250);
            log_records (
                gc_debug_flag,
                   SUBSTR (SQLERRM, 1, 250)
                || ' Exception in transfer_receipt_records procedure');
    END transfer_receipt_records;

    --truncte_stage_tables
    PROCEDURE truncte_stage_tables (x_ret_code      OUT VARCHAR2,
                                    x_return_mesg   OUT VARCHAR2)
    AS
        lx_return_mesg   VARCHAR2 (2000);
    BEGIN
        --x_ret_code   := gn_suc_const;
        fnd_file.put_line (
            fnd_file.LOG,
            'Working on truncte_stage_tables to purge the data');


        EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_INV_ITEM_ONHAND_QTY_STG_T';

        -- EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_INV_ITEM_ONHAND_PO_STG_T';
        --EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_INV_ITEM_ONHAND_REV_STG_T';

        fnd_file.put_line (fnd_file.LOG, 'Truncate Stage Table Complete');
    EXCEPTION
        WHEN OTHERS
        THEN
            --x_ret_code      := gn_err_const;
            x_return_mesg   := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'Truncate Stage Table Exception t' || x_return_mesg);
            xxd_common_utils.record_error ('INV', gn_org_id, 'Decker Inventory Item Onhand Conversion Program', --  SQLCODE,
                                                                                                                SQLERRM, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                              --   SYSDATE,
                                                                                                                                                              gn_user_id, gn_conc_request_id, 'truncte_stage_tables', NULL
                                           , x_return_mesg);
    END truncte_stage_tables;


    --
    --PROCEDURE inv_onhand_qty_child (x_retcode                                    OUT     NUMBER,
    --                x_errbuf                                     OUT     VARCHAR2,
    --                p_process                                     IN     VARCHAR2,
    --                p_debug_flag                                  IN     VARCHAR2
    --                                  )
    --AS
    --      x_errcode       VARCHAR2 (500);
    --      x_errmsg        VARCHAR2 (500);
    --      lc_debug_flag   VARCHAR2 (1);
    --      ln_process      NUMBER;
    --      ln_ret          NUMBER;
    --
    --    TYPE hdr_batch_id_t IS TABLE OF NUMBER
    --                                INDEX BY BINARY_INTEGER;
    --
    --      ln_hdr_batch_id        hdr_batch_id_t;
    --      lc_conlc_status        VARCHAR2 (150);
    --      ln_request_id          NUMBER := 0;
    --      lc_phase               VARCHAR2 (200);
    --      lc_status              VARCHAR2 (200);
    --      lc_dev_phase          VARCHAR2 (200);
    --      lc_dev_status         VARCHAR2 (200);
    --      lc_message             VARCHAR2 (200);
    --      ln_ret_code            NUMBER;
    --      lc_err_buff            VARCHAR2 (1000);
    --      ln_count               NUMBER;
    --      ln_cntr                NUMBER := 0;
    --      --      ln_batch_cnt          NUMBER                                   := 0;
    --      ln_parent_request_id   NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
    --      lb_wait                BOOLEAN;
    --      lx_return_mesg         VARCHAR2 (2000);
    --      ln_valid_rec_cnt       NUMBER;
    --      x_total_rec                NUMBER;
    --      x_validrec_cnt          NUMBER;
    --
    --
    --
    --      TYPE request_table IS TABLE OF NUMBER
    --                               INDEX BY BINARY_INTEGER;
    --
    --      l_req_id               request_table;
    --
    --   BEGIN
    --      gc_debug_flag := p_debug_flag;
    --
    --      IF p_process = gc_extract_only
    --      THEN
    --         IF p_debug_flag = 'Y'
    --         THEN
    --            gc_code_pointer := 'Calling Extract process  ';
    --            fnd_file.put_line (fnd_file.LOG,
    --                               'Code Pointer: ' || gc_code_pointer);
    --         END IF;
    --          truncte_stage_tables (x_ret_code =>  x_retcode, x_return_mesg => x_errbuf);
    --
    --            extract_1206_data
    --                                  ( x_total_rec        =>   x_total_rec
    --                                  , x_errbuf           =>   x_errbuf
    --                                  , x_retcode          =>   x_retcode
    --                                  );
    --         ELSIF p_process = gc_validate_only
    --         THEN
    --         log_records (gc_debug_flag,'Calling cust_item_validation :');
    --
    --         inv_onhand_qty_validation (x_retcode            => x_retcode,
    --                               x_errbuf             => x_errbuf,
    --                               p_process            => gc_new_status,
    --                               p_batch_number       => NULL);
    --       ELSIF p_process = gc_load_only
    --         THEN
    --      transfer_records(x_retcode            => x_retcode,
    --                       x_errbuf             => x_errbuf
    --                              );
    --
    --      END IF;
    --
    --
    --   EXCEPTION
    --      WHEN OTHERS
    --      THEN
    --         fnd_file.put_line (fnd_file.LOG,
    --                            'Code Pointer: ' || gc_code_pointer);
    --         fnd_file.put_line (
    --            fnd_file.LOG,
    --               'Error Messgae: '
    --            || 'Unexpected error in Customer_main_proc '
    --            || SUBSTR (SQLERRM, 1, 250));
    --         fnd_file.put_line (fnd_file.LOG, '');
    --         x_retcode := 2;
    --         x_errbuf :=
    --            'Error Message Customer_main_proc ' || SUBSTR (SQLERRM, 1, 250);
    --END inv_onhand_qty_child;

    --+=====================================================================================+
    -- |Procedure  :  customer_child                                                       |
    -- |                                                                                    |
    -- |Description:  This procedure is the Child Process which will validate and create the|
    -- |              Price list in QP 1223 instance                                        |
    -- |                                                                                    |
    -- | Parameters : p_batch_id, p_action                                                  |
    -- |              p_debug_flag, p_parent_req_id                                         |
    -- |                                                                                    |
    -- |                                                                                    |
    -- | Returns :     x_errbuf,  x_retcode                                                 |
    -- |                                                                                    |
    --+=====================================================================================+

    --Deckers AR Customer Conversion Program (Worker)
    PROCEDURE inv_onhand_qty_child (
        errbuf                   OUT VARCHAR2,
        retcode                  OUT VARCHAR2,
        p_debug_flag          IN     VARCHAR2 DEFAULT 'N',
        p_action              IN     VARCHAR2,
        p_batch_id            IN     NUMBER,
        p_parent_request_id   IN     NUMBER,
        p_operating_unit_id   IN     VARCHAR2,
        p_inventory_org_id    IN     VARCHAR2)
    AS
        le_invalid_param            EXCEPTION;
        ln_new_ou_id                hr_operating_units.organization_id%TYPE; --:= fnd_profile.value('ORG_ID');
        -- This is required in release 12 R12

        ln_request_id               NUMBER := 0;
        lc_username                 fnd_user.user_name%TYPE;
        lc_operating_unit           hr_operating_units.NAME%TYPE;
        lc_cust_num                 VARCHAR2 (5);
        lc_pri_flag                 VARCHAR2 (1);
        ld_start_date               DATE;
        ln_ins                      NUMBER := 0;
        lc_create_reciprocal_flag   VARCHAR2 (1) := gc_no_flag;
        --ln_request_id             NUMBER                     := 0;
        lc_phase                    VARCHAR2 (200);
        lc_status                   VARCHAR2 (200);
        lc_delc_phase               VARCHAR2 (200);
        lc_delc_status              VARCHAR2 (200);
        lc_message                  VARCHAR2 (200);
        ln_ret_code                 NUMBER;
        lc_err_buff                 VARCHAR2 (1000);
        ln_count                    NUMBER;
        l_target_org_id             NUMBER;
        lc_submit_openpo            VARCHAR2 (3);
    BEGIN
        gc_debug_flag        := p_debug_flag;
        gn_conc_request_id   := p_parent_request_id;

        --g_err_tbl_type.delete;
        BEGIN
            SELECT user_name
              INTO lc_username
              FROM fnd_user
             WHERE user_id = fnd_global.USER_ID;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_username   := NULL;
        END;

        BEGIN
            SELECT NAME
              INTO lc_operating_unit
              FROM hr_operating_units
             WHERE organization_id = fnd_profile.VALUE ('ORG_ID');
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_operating_unit   := NULL;
        END;



        -- Validation Process for Price List Import
        fnd_file.put_line (
            fnd_file.LOG,
            '*************************************************************************** ');
        fnd_file.put_line (
            fnd_file.LOG,
               '***************     '
            || lc_operating_unit
            || '***************** ');
        fnd_file.put_line (
            fnd_file.LOG,
            '*************************************************************************** ');
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Busines Unit:'
            || lc_operating_unit);
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Run By      :'
            || lc_username);
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Run Date    :'
            || TO_CHAR (gd_sys_date, 'DD-MON-YYYY HH24:MI:SS'));
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Request ID  :'
            || fnd_global.conc_request_id);
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Batch ID    :'
            || p_batch_id);
        fnd_file.new_line (fnd_file.LOG, 1);

        fnd_file.new_line (fnd_file.LOG, 1);
        fnd_file.new_line (fnd_file.LOG, 1);
        log_records (
            gc_debug_flag,
            '+---------------------------------------------------------------------------+');
        log_records (gc_debug_flag,
                     '******** START of Onhand Import Program ******');
        log_records (
            gc_debug_flag,
            '+---------------------------------------------------------------------------+');

        gc_debug_flag        := p_debug_flag;

        IF p_action = gc_validate_only
        THEN
            log_records (gc_debug_flag, 'Calling Onhand_validation :');

            inv_onhand_qty_validation (
                x_retcode          => RETCODE,
                x_errbuf           => ERRBUF,
                p_process          => gc_new_status,
                p_batch_number     => p_batch_id,
                P_OPERATING_UNIT   => p_operating_unit_id,
                P_INVENTORY_ORG    => p_inventory_org_id);
        ELSIF p_action = gc_load_only
        THEN
            log_records (gc_debug_flag, 'Calling transfer Load Po Records +');

            transfer_po_line_records (
                x_ret_code         => RETCODE,
                p_operating_unit   => p_operating_unit_id,
                p_inventory_org    => p_inventory_org_id);
        --        submit_po_request(p_batch_id => 999,p_org_id=> 87,p_submit_openpo => lc_submit_openpo)   ;
        --      ELSIF p_action = 'VALIDATE AND LOAD'
        --      THEN
        --         NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.output,
                'Exception Raised During Onhand Conversion Program');
            RETCODE   := 2;
            ERRBUF    := ERRBUF || SQLERRM;
    END inv_onhand_qty_child;

    /******************************************************
    * Procedure: Onhand_main_proc
    *
    * Synopsis: This procedure will call we be called by the concurrent program
    * Design:
    *
    * Notes:
    *
    * PARAMETERS:
    *   IN OUT: x_errbuf   Varchar2
    *   IN OUT: x_retcode  Varchar2
    *   IN    : p_process  varchar2
    *
    * Return Values:
    * Modifications:
    *
    ******************************************************/

    PROCEDURE main (x_retcode                OUT NUMBER,
                    x_errbuf                 OUT VARCHAR2,
                    p_process             IN     VARCHAR2,
                    p_debug_flag          IN     VARCHAR2,
                    p_no_of_process       IN     NUMBER,
                    p_operating_unit_id   IN     VARCHAR2,
                    p_inventory_org_id    IN     VARCHAR2,
                    P_TRANSACTION_DATE    IN     VARCHAR2)
    IS
        x_errcode                VARCHAR2 (500);
        x_errmsg                 VARCHAR2 (500);
        lc_debug_flag            VARCHAR2 (1);
        ln_process               NUMBER;
        ln_ret                   NUMBER;

        TYPE hdr_batch_id_t IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        ln_hdr_batch_id          hdr_batch_id_t;

        TYPE hdr_customer_process_t IS TABLE OF VARCHAR2 (250)
            INDEX BY BINARY_INTEGER;

        lc_hdr_customer_proc_t   hdr_customer_process_t;

        lc_conlc_status          VARCHAR2 (150);
        ln_request_id            NUMBER := 0;
        lc_phase                 VARCHAR2 (200);
        lc_status                VARCHAR2 (200);
        lc_dev_phase             VARCHAR2 (200);
        lc_dev_status            VARCHAR2 (200);
        lc_message               VARCHAR2 (200);
        ln_ret_code              NUMBER;
        lc_err_buff              VARCHAR2 (1000);
        ln_count                 NUMBER;
        ln_cntr                  NUMBER := 0;
        --      ln_batch_cnt          NUMBER        := 0;
        ln_parent_request_id     NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
        lb_wait                  BOOLEAN;
        lx_return_mesg           VARCHAR2 (2000);
        ln_valid_rec_cnt         NUMBER;
        x_total_rec              NUMBER;
        x_validrec_cnt           NUMBER;
        lc_submit_openpo         VARCHAR2 (3);
        lx_group_id              NUMBER;
        ln_po_status_flag        VARCHAR2 (3);
        v_from_lpn               NUMBER;
        v_to_lpn                 NUMBER;
        v_pack_pallet_lpn        BOOLEAN;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id                 request_table;
        v_opearting_unit_id      NUMBER;
        V_INVENTORY_ORG          NUMBER;

        CURSOR lcu_ou IS
            SELECT lookup_code org_id
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_1206_OU_MAPPING'
                   AND attribute1 = NVL (p_operating_unit_id, attribute1)
                   AND language = USERENV ('LANG');


        CURSOR lcu_1206_org IS
              SELECT DISTINCT mp.organization_code, mp.organization_id, ood.operating_unit,
                              hou.name
                FROM org_organization_definitions ood, mtl_parameters mp, fnd_lookup_values fl,
                     apps.hr_operating_units hou
               WHERE     ood.organization_id = mp.organization_id
                     AND fl.lookup_type = 'XXD_1206_INV_ORG_MAPPING'
                     AND fl.attribute1(+) = mp.organization_code
                     AND ood.operating_unit = hou.organization_id
                     AND hou.name = p_operating_unit_id
                     AND mp.organization_code =
                         NVL (p_inventory_org_id, mp.organization_code)
            ORDER BY mp.organization_code;

        CURSOR lcu_inv_org (P_INV_ORG VARCHAR2)
        IS
            SELECT TO_NUMBER (lookup_code) inventory_org_id, meaning Inventory_org_1206
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_1206_INV_ORG_MAPPING'
                   AND attribute1 = NVL (P_INV_ORG, attribute1)
                   AND language = USERENV ('LANG');
    BEGIN
        gc_debug_flag   := p_debug_flag;

        IF p_process = gc_extract_only
        THEN
            IF p_debug_flag = 'Y'
            THEN
                gc_code_pointer   := 'Calling Extract process  ';
                fnd_file.put_line (fnd_file.LOG,
                                   'Code Pointer: ' || gc_code_pointer);
            END IF;

            truncte_stage_tables (x_ret_code      => x_retcode,
                                  x_return_mesg   => x_errbuf);

            extract_1206_data (x_total_rec        => x_total_rec,
                               x_errbuf           => x_errbuf,
                               x_retcode          => x_retcode,
                               P_OPERATING_UNIT   => p_operating_unit_id,
                               p_inventory_org    => p_inventory_org_id);
        ELSIF p_Process = gc_validate_only
        THEN
            /* BEGIN
              SELECT  lookup_code
               INTO  v_opearting_unit_id
               FROM fnd_lookup_values
              WHERE lookup_type ='XXD_1206_OU_MAPPING'
               AND  attribute1 = NVL(p_operating_unit_id,attribute1)
               and language= USERENV('LANG');
              EXCEPTION
               WHEN OTHERS THEN
                v_opearting_unit_id := Null;
                 fnd_file.put_line (fnd_file.LOG,
                                    'Exception while fetching OU: ' || SQLERRM);
               END;*/
            FOR rec_ou IN lcu_ou
            LOOP
                v_opearting_unit_id   := rec_ou.org_id;

                FOR rec_1206_org IN lcu_1206_org
                LOOP
                    FOR i IN lcu_inv_org (rec_1206_org.organization_code)
                    LOOP
                        V_INVENTORY_ORG   := i.inventory_org_id;

                        BEGIN
                            UPDATE XXD_INV_ITEM_ONHAND_QTY_STG_T
                               SET batch_number = NULL, record_status = gc_new_status
                             WHERE     RECORD_STATUS IN
                                           (gc_new_status, gc_error_status)
                                   AND OPERATING_UNIT = v_opearting_unit_id
                                   AND INVENTORY_ORG = V_INVENTORY_ORG;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                NULL;
                        END;
                    END LOOP;
                END LOOP;
            END LOOP;

            SELECT COUNT (*)
              INTO ln_valid_rec_cnt
              FROM XXD_INV_ITEM_ONHAND_QTY_STG_T
             WHERE batch_number IS NULL AND RECORD_STATUS = gc_new_status;

            --AND OPERATING_UNIT = v_opearting_unit_id;

            --write_log ('Creating Batch id and update  XXD_AR_CUST_INT_STG_T');

            -- Create batches of records and assign batch id


            FOR i IN 1 .. p_no_of_process
            LOOP
                BEGIN
                    SELECT XXD_INV_ITEM_ONHAND_BATCH_SEQ.NEXTVAL
                      INTO ln_hdr_batch_id (i)
                      FROM DUAL;

                    log_records (
                        gc_debug_flag,
                        'ln_hdr_batch_id(i) := ' || ln_hdr_batch_id (i));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_hdr_batch_id (i + 1)   := ln_hdr_batch_id (i) + 1;
                END;

                log_records (gc_debug_flag,
                             ' ln_valid_rec_cnt := ' || ln_valid_rec_cnt);
                log_records (
                    gc_debug_flag,
                       'ceil( ln_valid_rec_cnt/p_no_of_process) := '
                    || CEIL (ln_valid_rec_cnt / p_no_of_process));

                UPDATE XXD_INV_ITEM_ONHAND_QTY_STG_T
                   SET batch_number = ln_hdr_batch_id (i), REQUEST_ID = ln_parent_request_id
                 WHERE     batch_number IS NULL
                       AND ROWNUM <=
                           CEIL (ln_valid_rec_cnt / p_no_of_process)
                       AND RECORD_STATUS = gc_new_status;
            -- AND  OPERATING_UNIT = NVL(v_opearting_unit_id,OPERATING_UNIT);



            END LOOP;

            log_records (
                gc_debug_flag,
                'completed updating Batch id in  XXD_INV_ITEM_ONHAND_QTY_STG_T');

            FOR i IN 1 .. ln_hdr_batch_id.COUNT
            LOOP
                SELECT COUNT (*)
                  INTO ln_cntr
                  FROM XXD_INV_ITEM_ONHAND_QTY_STG_T
                 WHERE record_status = gc_new_status;

                -- and  OPERATING_UNIT = NVL(v_opearting_unit_id,OPERATING_UNIT);


                IF ln_cntr > 0
                THEN
                    BEGIN
                        ln_request_id   :=
                            apps.fnd_request.submit_request (
                                'XXDCONV',
                                'XXDMTLONHANDQTYCNVCHLDCP',
                                '',
                                '',
                                FALSE,
                                p_debug_flag,
                                p_process,
                                ln_hdr_batch_id (i),
                                ln_parent_request_id,
                                p_operating_unit_id,
                                p_inventory_org_id);
                        log_records (gc_debug_flag,
                                     'v_request_id := ' || ln_request_id);

                        IF ln_request_id > 0
                        THEN
                            l_req_id (i)   := ln_request_id;
                            COMMIT;
                        ELSE
                            ROLLBACK;
                        END IF;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            x_retcode   := 2;
                            X_ERRBUF    := X_ERRBUF || SQLERRM;
                            log_records (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXDMTLONHANDQTYCNVCHLDCP error'
                                || SQLERRM);
                        WHEN OTHERS
                        THEN
                            x_retcode   := 2;
                            X_ERRBUF    := X_ERRBUF || SQLERRM;
                            log_records (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXDMTLONHANDQTYCNVCHLDCP error'
                                || SQLERRM);
                    END;
                END IF;
            END LOOP;
        --validate_cust_proc (x_errcode, x_errmsg, lc_debug_flag);
        ELSIF p_process = gc_load_po_only
        THEN
            log_records (
                gc_debug_flag,
                'Fetching batch id from XXD_INV_ITEM_ONHAND_QTY_STG_T stage to call worker process');
            ln_cntr   := 0;
            transfer_po_line_records (
                x_ret_code         => x_retcode,
                p_operating_unit   => p_operating_unit_id,
                p_inventory_org    => p_inventory_org_id);
            transfer_po_ret_line_records (
                x_ret_code         => x_retcode,
                p_operating_unit   => p_operating_unit_id,
                p_inventory_org    => p_inventory_org_id);
        ELSIF p_process = gc_load_recpt_only
        THEN
            --      transfer_po_line_records(x_ret_code     =>              x_retcode) ;

            FOR po
                IN (SELECT DISTINCT poh.po_header_id, organization_id, NEW_LOCATOR_ID,
                                    subinventory
                      FROM XXD_INV_ITEM_ONHAND_REV_STG_T xitr, po_headers_all poh
                     WHERE     poh.po_header_id = xitr.po_header_id
                           AND record_status = gc_new_status
                           AND organization_id =
                               (SELECT organization_id
                                  FROM hr_operating_units
                                 WHERE name = p_operating_unit_id)
                           AND AUTHORIZATION_STATUS = 'APPROVED')
            LOOP
                --         ln_po_status_flag := gc_yes_flag;
                --         IF get_po_status(p_po_header_id =>po.po_header_id ,p_organization_id => po.organization_id
                --         ) = 0 THEN
                --            ln_po_status_flag := gc_no_flag;
                --            UPDATE XXD_INV_ITEM_ONHAND_REV_STG_T SET
                --                        record_status = gc_error_status
                --                 WHERE po_header_id = po.po_header_id
                --                   AND ERROR_MSG    = 'PO is not in AUTHORIZATION_STATUS APPROVED or PO is Not available';
                --         ELSE
                transfer_receipt_records (
                    x_retcode            => x_retcode,
                    x_errbuf             => X_ERRBUF,
                    p_po_header_id       => po.po_header_id,
                    p_org_id             => po.organization_id,
                    P_TRANSACTION_DATE   => P_TRANSACTION_DATE,
                    x_group_id           => lx_group_id);
            --         ln_po_status_flag := gc_yes_flag;

            --         END IF;


            END LOOP;
        END IF;

        log_records (
            gc_debug_flag,
               'Calling XXD_INV_ITEM_ONHAND_REV_STG_T in batch '
            || ln_hdr_batch_id.COUNT);
        log_records (
            gc_debug_flag,
            'Calling WAIT FOR REQUEST XXD_INV_ITEM_ONHAND_REV_STG_T to complete');

        IF l_req_id.COUNT > 0
        THEN
            FOR rec IN l_req_id.FIRST .. l_req_id.LAST
            LOOP
                IF l_req_id (rec) > 0
                THEN
                    LOOP
                        lc_dev_phase    := NULL;
                        lc_dev_status   := NULL;
                        lb_wait         :=
                            fnd_concurrent.wait_for_request (
                                request_id   => l_req_id (rec) --ln_concurrent_request_id
                                                              ,
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
            END LOOP;
        END IF;

        IF p_Process = gc_validate_only
        THEN
            transfer_records (x_retcode => x_retcode, x_errbuf => x_errbuf);
        END IF;
    /* IF p_Process = gc_validate_only THEN
        update_po_records( x_retcode             => x_retcode,
                          x_errbuf              => x_errbuf
                        );
     END IF;*/


    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Code Pointer: ' || gc_code_pointer);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Messgae: '
                || 'Unexpected error in main '
                || SUBSTR (SQLERRM, 1, 250));
            fnd_file.put_line (fnd_file.LOG, '');
            x_retcode   := 2;
            x_errbuf    := 'Error Message main ' || SUBSTR (SQLERRM, 1, 250);
    END main;
END XXD_INV_ITEM_ONHAND_QTY_PKG;
/
