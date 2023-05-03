--
-- XXD_WMS_HJ_INT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:52 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_WMS_HJ_INT_PKG"
AS
    /********************************************************************************************************************
    $Header:  xxd_wms_hj_int_pkg.sql   1.0    2018/04/04    10:00:00   Kbollam $
    *********************************************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    /* NAME:        xxont_pick_proc_ext_pkg (Previous Design Package Name)
    --              xxd_wms_hj_int_pkg (Redesigned Package Name for CCR0007089(Change 2.0))
    --
    -- Description  :  This is package Body for EBS to WMS pick ticket details
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY

    Ver     Date        Author              Description
    ------  ----------  ------------        ------------------------------------
    1.0     7/7/2014    Infosys             Created initial version.
    2.0     04/04/2018  Kranthi Bollam      CCR0007089 - Redesign changes. Decoupled extraction and file generation into two parts.
                                            Only pick ticket extraction and loading into staging tables to be handled by EBS.
                                            Moved Pick ticket XML file generation and transfer to SOA.
    2.1     21/06/2018  Kranthi Bollam      CCR0007376 - fixed the issue where the cursor should not extract/pull the Pick tickets status
                                            in header staging table is in INPROCESS or NEW
    2.2     01/15/2019  Krishna L           CCR0007638 - Customer and STYLE VAS for TEVA BagtoBox
    2.3     02/06/2019  Kranthi Bollam      CCR0007774 - Logic change in Deriving updated Deliveries and also perfomance improvements
                                            Resolved a PROD bug where SOA is generating files with header data only as the batch number is updated at header but not
                                            at line when a SOA call is made. This is caused as the header update is committed but the lines are still being updated.
                                            So, now committing the header and lines batch number update at the end.
                                            Also addressed a Delivery Detail Split scenario
                                            --10.3    Return address info Change for DTC orders(Drop Ship Orders)
                                            --10.4    Freight Terms code
    2.4     08/12/2019  Kranthi Bollam      CCR0008171 - Revert the Freight Terms Code Changes done as part of CCR0007774(10.4)
    2.5     10/24/2019  Tejaswi Gangumalla  CCR0008279(10.6) - Restrict "Planned for Cross docking" status orders to HJ
    2.6     12/17/2019  Aravind Kannuri     CCR0008348(10.7) - Pick Ticket Integration Enhancements
    3.0     03/18/2020  Srinath Siricilla   CCR0008436 - Pack Slip Project Customization
    3.1     01/06/2021  Viswanathan Pandian CCR0009119 - Performance fix
    4.0     08/10/2020  Greg Jensen         CCR0008657 - VAS Automation
    4.1     04/15/2021  Suraj Valluri       US6
    4.2     08/06/2021  Balavenu Rao        CCR0009359  -- Retail Unit Price Mapping (Customer Item Price) change
    4.3     04/05/2022  Aravind Kannuri     CCR0009932  -- Incorrect status of Pick Ticket log tables
    4.4     09/08/2021  Greg Jensen         CCR0009572 - Access Point /HubBox update for e-comm
    *********************************************************************************************************************/

    --Global Variables Declaration
    c_num_debug                    NUMBER := 0;
    c_dte_sysdate                  DATE := SYSDATE;
    g_num_user_id                  NUMBER := fnd_global.user_id;
    g_num_resp_id                  NUMBER := fnd_global.resp_id;
    g_num_resp_appl_id             NUMBER := fnd_global.resp_appl_id;
    g_num_login_id                 NUMBER := fnd_global.login_id;
    g_num_request_id               NUMBER := fnd_global.conc_request_id;
    g_num_prog_appl_id             NUMBER := fnd_global.prog_appl_id;
    g_num_session_id               NUMBER := fnd_global.session_id;
    g_dt_current_date              DATE := SYSDATE;
    g_num_rec_count                NUMBER := 0;
    gc_new_status         CONSTANT VARCHAR2 (15) := 'NEW';
    gc_inprocess_status   CONSTANT VARCHAR2 (15) := 'INPROCESS';
    gc_processed_status   CONSTANT VARCHAR2 (15) := 'PROCESSED';
    gc_error_status       CONSTANT VARCHAR2 (15) := 'ERROR';
    gc_obsolete_status    CONSTANT VARCHAR2 (15) := 'OBSOLETE';
    gc_warning_status     CONSTANT VARCHAR2 (15) := 'WARNING';
    gc_package_name       CONSTANT VARCHAR2 (30) := 'XXD_WMS_HJ_INT_PKG';
    gc_program_name       CONSTANT VARCHAR2 (120) := 'EBS_HJ_PICK_TICKET_INT';
    gc_period_char        CONSTANT VARCHAR2 (1) := '.';
    gc_soa_user           CONSTANT NUMBER := -999;
    gn_reprocess_hours    CONSTANT NUMBER
        := NVL (
               fnd_profile.value_specific (
                   NAME      => 'XXD_WMS_HJ_PICK_TKT_REPROCESS_HOURS',
                   user_id   => g_num_user_id)              --User Level Value
                                              ,
               fnd_profile.VALUE ('XXD_WMS_HJ_PICK_TKT_REPROCESS_HOURS') --Site Level Value
                                                                        ) ;
    gn_inv_org_id                  NUMBER := NULL;

    TYPE vas_codes_type IS RECORD
    (
        vas_code    VARCHAR2 (20)
    );

    TYPE vas_code_type_tbl IS TABLE OF vas_codes_type
        INDEX BY BINARY_INTEGER;

    rec_vas_str                    vas_code_type_tbl;

    /*********************************************************************************
    Procedure/Function Name  :  msg
    Description              :  This procedure displays log messages based on debug
                                mode parameter
    *********************************************************************************/
    PROCEDURE msg (in_chr_message VARCHAR2)
    IS
    BEGIN
        IF c_num_debug = 1
        THEN
            fnd_file.put_line (fnd_file.LOG, in_chr_message);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Unexpected Error: ' || SQLERRM);
    END;

    --Procedure to write debug messages into Interface errors table
    PROCEDURE debug_prc (pv_application IN VARCHAR2, pv_debug_text IN VARCHAR2, pv_debug_message IN VARCHAR2, pn_created_by IN NUMBER, pn_session_id IN NUMBER, pn_debug_id IN NUMBER
                         , pn_request_id IN NUMBER)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        lv_proc_name   VARCHAR2 (30) := 'DEBUG_PRC';
        lv_err_msg     VARCHAR2 (2000) := NULL;
    BEGIN
        INSERT INTO custom.do_debug (debug_text, creation_date, created_by,
                                     session_id, debug_id, request_id,
                                     application_id, call_stack)
             VALUES (pv_debug_text                                --debug_text
                                  , SYSDATE                    --creation_Date
                                           , NVL (pn_created_by, -1) --created_by
                                                                    ,
                     NVL (pn_session_id, SYS_CONTEXT ('USERENV', 'SESSIONID')), --session_id
                                                                                NVL (pn_debug_id, -1) --debug_id
                                                                                                     , NVL (pn_request_id, g_num_request_id) --request_id
                     , pv_application                         --application_id
                                     , pv_debug_message           --call_stack
                                                       );

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_err_msg   :=
                   'Error while purging the debug messages in '
                || gc_package_name
                || '.'
                || lv_proc_name;
            lv_err_msg   :=
                SUBSTR (lv_err_msg || '. Error is : ' || SQLERRM, 1, 2000);

            IF g_num_resp_id <> -1
            THEN
                msg (lv_err_msg);        --Print the error message to log file
            END IF;
    END debug_prc;

    PROCEDURE parse (p_move_next   IN OUT BOOLEAN,
                     p_string      IN OUT VARCHAR2,
                     p_vas_code    IN OUT VARCHAR2)
    AS
        l_proc_name   VARCHAR2 (30) := 'PARSE';
        l_err_msg     VARCHAR2 (2000) := NULL;
    BEGIN
        IF p_move_next = TRUE
        THEN
            IF LENGTH (p_string) > 0 AND (INSTR (p_string, '+')) <> 0
            THEN
                p_vas_code   :=
                    SUBSTR (p_string, 1, (INSTR (p_string, '+') - 1));
                p_string   :=
                    SUBSTR (p_string,
                            (INSTR (p_string, '+') + 1),
                            (LENGTH (p_string) - (INSTR (p_string, '+'))));
            ELSE
                p_vas_code    := p_string;
                p_string      := NULL;
                p_move_next   := FALSE;
            END IF;
        END IF;
    --Added exception for change 2.0
    EXCEPTION
        WHEN OTHERS
        THEN
            p_vas_code    := NULL;
            p_string      := NULL;
            p_move_next   := FALSE;
            l_err_msg     :=
                SUBSTR (
                    'Exception in PARSE procedure. Error is: ' || SQLERRM,
                    1,
                    2000);
            fnd_file.put_line (fnd_file.LOG, l_err_msg);
    --msg('Exception in PARSE procedure. Error is: '||SQLERRM);
    END parse;

    /**********************************************************************************
    Procedure/Function Name  :  parse_attributes
    Description              :  This function looks for a particular attribute in a
                                search string and returns the attribute value.
                                assumption is string format is "attr1:val,attr2:val,attr3:val"
    **********************************************************************************/
    FUNCTION parse_attributes (p_attributes      IN VARCHAR2,
                               p_search_string   IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_func_name       VARCHAR2 (30) := 'PARSE_ATTRIBUTES';
        l_pos             INTEGER;
        l_temp            VARCHAR2 (240);
        l_search_string   VARCHAR2 (240)
            := SUBSTR (REPLACE (p_search_string, ':', ''), 1, 240);
        l_err_msg         VARCHAR2 (2000) := NULL;
    BEGIN
        l_pos    := INSTR (p_attributes, l_search_string);

        IF (l_pos = 0)
        THEN
            RETURN '';
        END IF;

        l_pos    := l_pos + LENGTH (l_search_string) + 1;
        l_temp   := SUBSTR (p_attributes, l_pos);
        l_pos    := INSTR (l_temp, ',');

        IF (l_pos = 0)
        THEN
            RETURN l_temp;
        END IF;

        l_temp   := SUBSTR (l_temp, 0, l_pos - 1);
        RETURN l_temp;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_err_msg   :=
                SUBSTR (
                       'Exception in '
                    || l_func_name
                    || '. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            msg (l_err_msg);
    END parse_attributes;

    /**********************************************************************************
    Procedure/Function Name  :  GET_LAST_RUN_TIME
    Description              :  This function looks for warehouse and sales channel
                                combination and return the last run date/time.
    **********************************************************************************/
    FUNCTION get_last_run_time (pn_warehouse_id    IN NUMBER,
                                pv_sales_channel   IN VARCHAR2)
        RETURN DATE
    IS
        --Local Variables Declaration
        l_func_name        VARCHAR2 (30) := 'GET_LAST_RUN_TIME';
        l_err_msg          VARCHAR2 (2000) := NULL;
        ld_last_run_date   DATE := NULL;
    BEGIN
        SELECT TO_DATE (flv.attribute3, 'RRRR/MM/DD HH24:MI:SS') last_run_date
          INTO ld_last_run_date
          FROM fnd_lookup_values flv
         WHERE     1 = 1
               AND flv.lookup_type = 'XXD_WMS_HJ_PICK_RUN_LKP'
               AND flv.LANGUAGE = USERENV ('LANG')
               AND flv.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE)
                               AND NVL (flv.end_date_active, SYSDATE + 1)
               AND TO_NUMBER (flv.attribute1) = pn_warehouse_id
               AND flv.attribute2 = pv_sales_channel;

        RETURN ld_last_run_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_err_msg   :=
                SUBSTR (
                       'Exception in '
                    || l_func_name
                    || '. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            msg (l_err_msg);
            RETURN NULL;
    END get_last_run_time;

    --Added below procedure for change 2.0 to set the program last run time for Warehouse and sales channel
    /**********************************************************************************
    Procedure/Function Name  :  SET_LAST_RUN_TIME
    Description              :  This Procedure looks for warehouse and sales channel
                                combination and updates the last run date/time.
    **********************************************************************************/
    PROCEDURE set_last_run_time (pn_warehouse_id IN NUMBER, pv_sales_channel IN VARCHAR2, pd_last_run_date IN DATE)
    IS
        --Local Variables Declaration
        l_proc_name   VARCHAR2 (30) := 'SET_LAST_RUN_TIME';
        l_err_msg     VARCHAR2 (2000) := NULL;

        CURSOR upd_lkp_cur IS
            SELECT flv.*
              FROM apps.fnd_lookup_values flv
             WHERE     1 = 1
                   AND flv.lookup_type = 'XXD_WMS_HJ_PICK_RUN_LKP'
                   AND flv.LANGUAGE = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE)
                                   AND NVL (flv.end_date_active, SYSDATE + 1)
                   AND TO_NUMBER (flv.attribute1) = pn_warehouse_id
                   AND flv.attribute2 = pv_sales_channel;
    BEGIN
        FOR upd_lkp_rec IN upd_lkp_cur
        LOOP
            fnd_lookup_values_pkg.update_row (
                x_lookup_type           => upd_lkp_rec.lookup_type,
                x_security_group_id     => upd_lkp_rec.security_group_id,
                x_view_application_id   => upd_lkp_rec.view_application_id,
                x_lookup_code           => upd_lkp_rec.lookup_code,
                x_tag                   => upd_lkp_rec.tag,
                x_attribute_category    => upd_lkp_rec.attribute_category,
                x_attribute1            => upd_lkp_rec.attribute1,
                x_attribute2            => upd_lkp_rec.attribute2,
                x_attribute3            =>
                    TO_CHAR (pd_last_run_date, 'RRRR/MM/DD HH24:MI:SS'),
                x_attribute4            => upd_lkp_rec.attribute4,
                x_enabled_flag          => upd_lkp_rec.enabled_flag,
                x_start_date_active     => upd_lkp_rec.start_date_active,
                x_end_date_active       => upd_lkp_rec.end_date_active,
                x_territory_code        => upd_lkp_rec.territory_code,
                x_attribute5            => upd_lkp_rec.attribute5,
                x_attribute6            => upd_lkp_rec.attribute6,
                x_attribute7            => upd_lkp_rec.attribute7,
                x_attribute8            => upd_lkp_rec.attribute8,
                x_attribute9            => upd_lkp_rec.attribute9,
                x_attribute10           => upd_lkp_rec.attribute10,
                x_attribute11           => upd_lkp_rec.attribute11,
                x_attribute12           => upd_lkp_rec.attribute12,
                x_attribute13           => upd_lkp_rec.attribute13,
                x_attribute14           => upd_lkp_rec.attribute14,
                x_attribute15           => upd_lkp_rec.attribute15,
                x_meaning               => upd_lkp_rec.meaning,
                x_description           => upd_lkp_rec.description,
                x_last_update_date      => SYSDATE,
                x_last_updated_by       => g_num_user_id,
                x_last_update_login     => g_num_login_id);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Updated LAST_RUN_DATE for warehouse ID = '
                || upd_lkp_rec.attribute1
                || ' , Sales Channel = '
                || upd_lkp_rec.attribute2
                || ' to '
                || TO_CHAR (pd_last_run_date, 'RRRR/MM/DD HH24:MI:SS'));
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_err_msg   :=
                SUBSTR (
                       'Exception in '
                    || l_proc_name
                    || ' while updating last run date. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            fnd_file.put_line (fnd_file.LOG, l_err_msg);
            msg (l_err_msg);
    END set_last_run_time;

    -- Start changes for CCR0008657
    FUNCTION get_vas_param_value (pn_header_id           IN NUMBER,
                                  pn_sold_to_org_id      IN NUMBER,
                                  pn_ship_to_org_id      IN NUMBER,
                                  pn_inventory_item_id   IN NUMBER := NULL,
                                  pv_parameter_name      IN VARCHAR)
        RETURN VARCHAR
    IS
        lv_party_name              VARCHAR2 (400);
        lv_party_site_name         VARCHAR2 (400);
        lv_account_number          VARCHAR2 (400);
        lv_account_name            VARCHAR2 (400);
        lv_cust_po_number          VARCHAR2 (400);
        lv_order_number            VARCHAR2 (400);
        lv_ordered_item            VARCHAR2 (400);
        lv_retail_price            VARCHAR2 (400);
        lv_customer_item_number    VARCHAR2 (400);
        lv_assortment_id           VARCHAR2 (400);
        lv_assortment_qty          VARCHAR2 (400);
        lv_location_name           VARCHAR2 (400);

        lv_mc_max_height           VARCHAR2 (400);
        lv_mc_max_length           VARCHAR2 (400);
        lv_mc_max_weight           VARCHAR2 (400);
        lv_mc_max_width            VARCHAR2 (400);
        lv_mc_min_height           VARCHAR2 (400);
        lv_mc_min_length           VARCHAR2 (400);
        lv_mc_min_weight           VARCHAR2 (400);
        lv_mc_min_width            VARCHAR2 (400);
        lv_call_in_sla             VARCHAR2 (400);
        lv_ftl_pallet_flag         VARCHAR2 (400);
        lv_gs1_justification       VARCHAR2 (400);
        lv_gs1_mc_panel            VARCHAR2 (400);
        lv_routing_contact_email   VARCHAR2 (400);
        lv_routing_notes           VARCHAR2 (400);
        lv_scheduled_day1          VARCHAR2 (400);
        lv_tms_password            VARCHAR2 (400);
        lv_tms_url                 VARCHAR2 (400);
        lv_tms_username            VARCHAR2 (400);

        ln_item_level              NUMBER;
    BEGIN
        BEGIN
            --Set for item_level parameterrs
            CASE pv_parameter_name
                WHEN 'SKU'
                THEN
                    ln_item_level   := 1;
                WHEN 'RETAIL_PRICE'
                THEN
                    ln_item_level   := 1;
                WHEN 'ITEM_NUMBER'
                THEN
                    ln_item_level   := 1;
                WHEN 'QTY'
                THEN
                    ln_item_level   := 1;
                WHEN 'CUSTOMER_ITEM_NUMBER'
                THEN
                    ln_item_level   := 1;
                WHEN 'CUSTOMER_SKU'
                THEN
                    ln_item_level   := 1;
                ELSE
                    ln_item_level   := 0;
            END CASE;


            SELECT DISTINCT
                   acct.party_name,
                   NVL (acct.party_site_name, acct.party_name)
                       party_site_name,
                   ooha.order_number,
                   CASE ln_item_level
                       WHEN 1
                       THEN
                           /*TRIM (
                               SUBSTR (
                                   oola.attribute3,
                                   (INSTR (oola.attribute3, ':', 1)) + 1,
                                     (INSTR (oola.attribute3, ',', 1))
                                   - (INSTR (oola.attribute3, ':', 1))
                                   - 1)) */
                           --commented by KL

                           xxd_wms_hj_int_pkg.parse_attributes (
                               oola.attribute3,
                               'vendor_sku')
                       ELSE
                           NULL
                   END
                       assortment_id,
                   CASE ln_item_level
                       WHEN 1
                       THEN
                           /*TRIM (SUBSTR (oola.attribute3,
                                           (INSTR (oola.attribute3,
                                                   ':',
                                                   1,
                                                   2))
                                         + 1))*/
                           --commented by KL
                           xxd_wms_hj_int_pkg.parse_attributes (
                               oola.attribute3,
                               'casepack_qty')
                       ELSE
                           NULL
                   END
                       assortment_qty,
                   CASE ln_item_level
                       WHEN 1 THEN oola.ordered_item
                       ELSE NULL
                   END
                       ordered_item,
                   ooha.cust_po_number,
                   CASE ln_item_level
                       WHEN 1 THEN oola.attribute7
                       ELSE NULL
                   END
                       customer_item_number,
                   CASE ln_item_level
                       WHEN 1 THEN oola.attribute10
                       ELSE NULL
                   END
                       retail_price,
                   acct.account_number,
                   acct.account_name,
                   h.mc_max_height,
                   h.mc_max_length,
                   h.mc_max_weight,
                   h.mc_max_width,
                   h.mc_min_height,
                   h.mc_min_length,
                   h.mc_min_weight,
                   h.mc_min_width,
                   acct.location,
                   NVL (st.CALL_IN_SLA, h.CALL_IN_SLA)
                       CALL_IN_SLA,
                   NVL (st.FTL_PALLET_FLAG, h.FTL_PALLET_FLAG)
                       FTL_PALLET_FLAG,
                   NVL (st.GS1_JUSTIFICATION, h.GS1_JUSTIFICATION)
                       GS1_JUSTIFICATION,
                   NVL (st.GS1_MC_PANEL, h.GS1_MC_PANEL)
                       GS1_MC_PANEL,
                   NVL (st.ROUTING_CONTACT_EMAIL, h.ROUTING_CONTACT_EMAIL)
                       ROUTING_CONTACT_EMAIL,
                   NVL (st.ROUTING_NOTES, h.ROUTING_NOTES)
                       ROUTING_CONTACT_EMAIL,
                   NVL (st.SCHEDULED_DAY1, h.SCHEDULED_DAY1)
                       ROUTING_CONTACT_EMAIL,
                   NVL (st.TMS_PASSWORD, h.TMS_PASSWORD)
                       TMS_PASSWORD,
                   NVL (st.TMS_URL, h.TMS_URL)
                       TMS_URL,
                   NVL (st.TMS_USERNAME, h.TMS_USERNAME)
                       TMS_USERNAME
              INTO lv_party_name, lv_party_site_name, lv_order_number, lv_assortment_id,
                                lv_assortment_qty, lv_ordered_item, lv_cust_po_number,
                                lv_customer_item_number, lv_retail_price, lv_account_number,
                                lv_account_name, lv_mc_max_height, lv_mc_max_length,
                                lv_mc_max_weight, lv_mc_max_width, lv_mc_min_height,
                                lv_mc_min_length, lv_mc_min_weight, lv_mc_min_width,
                                lv_location_name, lv_call_in_sla, lv_ftl_pallet_flag,
                                lv_gs1_justification, lv_gs1_mc_panel, lv_routing_contact_email,
                                lv_routing_notes, lv_scheduled_day1, lv_tms_password,
                                lv_tms_url, lv_tms_username
              FROM oe_order_headers_all ooha,
                   oe_order_lines_all oola,
                   (SELECT hzca.cust_account_id, hzca.account_name, hzca.account_number,
                           hzcsu.site_use_id, hzcsu.location, hzps.party_site_name,
                           hzps.party_site_id, hzps.party_site_number, hzp.party_name
                      FROM hz_cust_accounts hzca, hz_cust_acct_sites_all hzcasa, hz_cust_site_uses_all hzcsu,
                           hz_party_sites hzps, hz_parties hzp
                     WHERE     hzca.cust_account_id = hzcasa.cust_account_id
                           AND hzcsu.cust_acct_site_id =
                               hzcasa.cust_acct_site_id
                           AND hzcasa.party_site_id = hzps.party_site_id
                           AND hzps.party_id = hzp.party_id) acct,
                   xxd_ont_customer_shipto_info_t st,
                   xxd_ont_customer_header_info_t h
             WHERE     1 = 1
                   AND oola.sold_to_org_id = pn_sold_to_org_id
                   AND ooha.header_id = pn_header_id
                   AND oola.ship_to_org_id = pn_ship_to_org_id
                   AND ooha.header_id = oola.header_id
                   AND CASE ln_item_level
                           WHEN 1 THEN pn_inventory_item_id
                           ELSE oola.inventory_item_id
                       END = oola.inventory_item_id
                   AND NVL (
                           oola.deliver_to_org_id,
                           NVL (oola.deliver_to_org_id, oola.ship_to_org_id)) =
                       acct.site_use_id
                   AND oola.sold_to_org_id = st.cust_account_id(+)
                   AND NVL (
                           oola.deliver_to_org_id,
                           NVL (oola.deliver_to_org_id, oola.ship_to_org_id)) =
                       st.ship_to_site_id(+)                --Check col change
                   AND oola.sold_to_org_id = h.cust_account_id(+);
        EXCEPTION
            WHEN OTHERS
            THEN
                RETURN NULL;
        END;

        --pass back field based on parameter
        CASE pv_parameter_name
            WHEN 'ACCOUNT_NUMBER'
            THEN
                RETURN lv_account_name;
            WHEN 'CUSTOMER_NAME'
            THEN
                RETURN lv_party_name;
            WHEN 'DESTINATION'
            THEN                                        --Hzcsua.location_name
                RETURN lv_party_site_name;
            WHEN 'CUSTOMER_PO_NUMBER'
            THEN
                RETURN lv_cust_po_number;
            WHEN 'SKU'
            THEN
                RETURN lv_ordered_item;
            WHEN 'RETAIL_PRICE'
            THEN
                RETURN lv_retail_price;
            WHEN 'ITEM_NUMBER'
            THEN
                RETURN lv_assortment_id;
            WHEN 'QTY'
            THEN
                RETURN lv_assortment_qty;
            WHEN 'CUSTOMER_ITEM_NUMBER'
            THEN
                RETURN lv_customer_item_number;
            WHEN 'CUSTOMER_SKU'
            THEN
                RETURN lv_customer_item_number;
            WHEN 'MC_MAX_HEIGHT'
            THEN
                RETURN lv_mc_max_height;
            WHEN 'MC_MAX_LENGTH'
            THEN
                RETURN lv_mc_max_length;
            WHEN 'MC_MAX_WEIGHT'
            THEN
                RETURN lv_mc_max_weight;
            WHEN 'MC_MAX_WIDTH'
            THEN
                RETURN lv_mc_max_width;
            WHEN 'MC_MIN_HEIGHT'
            THEN
                RETURN lv_mc_min_height;
            WHEN 'MC_MIN_LENGTH'
            THEN
                RETURN lv_mc_min_length;
            WHEN 'MC_MIN_WEIGHT'
            THEN
                RETURN lv_mc_min_weight;
            WHEN 'MC_MIN_WIDTH'
            THEN
                RETURN lv_mc_min_width;
            WHEN 'CALL_IN_SLA'
            THEN
                RETURN lv_call_in_sla;
            WHEN 'FTL_PALLET_FLAG'
            THEN
                RETURN lv_ftl_pallet_flag;
            WHEN 'JUSTIFY_FROM'
            THEN
                RETURN lv_gs1_justification;
            WHEN 'MC_PANEL'
            THEN
                RETURN lv_gs1_mc_panel;
            WHEN 'ROUTING_CONTACT_EMAIL'
            THEN
                RETURN lv_routing_contact_email;
            WHEN 'ROUTING_NOTES'
            THEN
                RETURN lv_routing_notes;
            WHEN 'SCHEDULED_DAY1'
            THEN
                RETURN lv_scheduled_day1;
            WHEN 'TMS_PASSWORD'
            THEN
                RETURN lv_tms_password;
            WHEN 'TMS_URL'
            THEN
                RETURN lv_tms_url;
            WHEN 'TMS_USERNAME'
            THEN
                RETURN lv_tms_username;
            ELSE
                RETURN NULL;
        END CASE;


        RETURN NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_order_attchments (p_order_number   IN NUMBER,
                                   p_category       IN VARCHAR2)
        RETURN VARCHAR2
    AS
        x_file_data   VARCHAR2 (2000);

        CURSOR get_lob_c IS
            SELECT REGEXP_REPLACE (REPLACE (REPLACE (REPLACE (UTL_RAW.CAST_TO_VARCHAR2 (DBMS_LOB.SUBSTR (fl.file_data, 2000, 1)), '>'), '<'), '&'), ' +', ' ') file_data
              FROM fnd_documents fd, fnd_lobs fl
             WHERE     1 = 1
                   AND fl.file_id = fd.media_id
                   AND fd.document_id =
                       (SELECT MAX (document_id)
                          FROM fnd_attached_docs_form_vl fad, fnd_document_categories_vl fdcv, oe_order_headers_all ooha,
                               wsh_delivery_details wdd, wsh_delivery_assignments wda
                         WHERE     fad.category_id = fdcv.category_id
                               AND fad.pk1_value = TO_CHAR (ooha.header_id)
                               AND fad.category_description =
                                   DECODE (
                                       p_category,
                                       'SHIPPING', 'OM - Shipping Instructions',
                                       'PACKING', 'OM - Packing Instructions',
                                       'TICKETING', 'OM - Pick Ticket Instructions')
                               AND wda.delivery_id = p_order_number
                               AND wda.delivery_detail_id =
                                   wdd.delivery_detail_id
                               AND wdd.source_code = 'OE'
                               AND wdd.source_header_id = ooha.header_id);
    BEGIN
        OPEN get_lob_c;

        FETCH get_lob_c INTO x_file_data;

        CLOSE get_lob_c;

        RETURN x_file_data;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_order_attchments;

    -- End changes for CCR0008657

    PROCEDURE process_vas_code (p_vas_1     IN     VARCHAR2,
                                p_vas_tbl      OUT vas_code_type_tbl)
    IS
        l_proc_name          VARCHAR2 (30) := 'PROCESS_VAS_CODE';
        l_err_msg            VARCHAR2 (2000) := NULL;
        lv_message           VARCHAR2 (500);
        lv_string1           VARCHAR2 (4000);
        lv_move_next         BOOLEAN;
        lv_vas_code_val      VARCHAR2 (10);
        lv_vas_code_exists   BOOLEAN;
        lv_count             NUMBER;
        lv_retcode           NUMBER := 0;
    BEGIN
        lv_string1     := p_vas_1;
        lv_move_next   := TRUE;
        lv_count       := 0;

        --String Parsing started
        WHILE ((lv_string1 IS NOT NULL) AND (LENGTH (lv_string1) > 0))
        LOOP
            parse (p_move_next   => lv_move_next,
                   p_string      => lv_string1,
                   p_vas_code    => lv_vas_code_val);
            msg (
                   'Plant code fetched through Parse procedure is '
                || lv_vas_code_val);
            lv_count                        := lv_count + 1;
            p_vas_tbl (lv_count).vas_code   := lv_vas_code_val;
        END LOOP;
    --Parsing ends
    EXCEPTION
        WHEN OTHERS
        THEN
            -- lv_return_status  := fnd_api.g_ret_sts_error;
            l_err_msg   :=
                SUBSTR (
                       'Exception in '
                    || l_proc_name
                    || ' While parsing VAS CODE. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            fnd_file.put_line (fnd_file.LOG, l_err_msg);
            msg (l_err_msg);
    END process_vas_code;

    /*
    ***********************************************************************************
     Procedure/Function Name  :  verify_vas_code -- Added for CCR0007638
     Description              :  This procedure looks for VAS defined at customer and not present on orders
                                 As of now we look into VAS defined at customer level
    **********************************************************************************
    */
    PROCEDURE verify_vas_code (p_customer_code   IN     VARCHAR2,
                               p_vas_tbl         IN OUT vas_code_type_tbl)
    IS
        TYPE t_tab IS TABLE OF VARCHAR2 (20);

        l_func_name      VARCHAR2 (30) := 'VERIFY_VAS_CODE';
        l_vas_code_tbl   vas_code_type_tbl;
        l_vas_tab        t_tab;

        CURSOR customer_vas IS
              SELECT title
                FROM apps.fnd_documents_vl doc, apps.oe_attachment_rules_v rule, apps.oe_attachment_rule_elements_v ele,
                     apps.xxd_ra_customers_v cust
               WHERE     doc.category_description = 'VAS Codes'
                     AND doc.document_id = rule.document_id
                     AND rule.rule_id = ele.rule_id
                     AND ele.attribute_name = 'Customer'
                     AND cust.customer_number = p_customer_code
                     AND ele.attribute_value = cust.customer_id
            ORDER BY title;

        l_vas_str        VARCHAR2 (1000);
        l_str            VARCHAR2 (1000);
        l_vascode_cnt    NUMBER;
        l_err_msg        VARCHAR2 (2000);
    BEGIN
        l_vas_code_tbl   := p_vas_tbl;
        l_vascode_cnt    := 0;

        /* Read the pre-existing order VAS codes into a string */
        IF l_vas_code_tbl.COUNT > 0
        THEN
            FOR i IN l_vas_code_tbl.FIRST .. l_vas_code_tbl.LAST
            LOOP
                l_vas_str       :=
                    l_vas_str || l_vas_code_tbl (i).vas_code || ',';
                l_vascode_cnt   := i;
            END LOOP;
        END IF;

        /* Insert them into a table type */
        l_vas_str        := LTRIM (l_vas_str, ',');
        l_vas_tab        := t_tab (l_str);

        /*Loop through VAS codes defined at customer level and check aginst the string
        Insert the missing into table type for extraction */
        FOR rec IN customer_vas
        LOOP
            IF rec.title MEMBER OF l_vas_tab
            THEN
                NULL;
            ELSE
                l_vascode_cnt                             := l_vascode_cnt + 1;
                l_vas_code_tbl (l_vascode_cnt).vas_code   := rec.title;
            END IF;
        END LOOP;

        p_vas_tbl        := l_vas_code_tbl;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_err_msg   :=
                SUBSTR (
                       'Exception in '
                    || l_func_name
                    || 'for customer#'
                    || p_customer_code
                    || '. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            fnd_file.put_line (fnd_file.LOG, l_err_msg);
    END verify_vas_code;

    --Added below procedure for change 2.0 to update orders by batch number
    --This procedure is called by SOA process to update process status of pick tickets for batch number
    -- Added p_org_code for US6 change
    PROCEDURE upd_batch_process_sts (p_batch_number    IN     NUMBER,
                                     p_from_status     IN     VARCHAR2,
                                     p_to_status       IN     VARCHAR2,
                                     x_update_status      OUT VARCHAR2,
                                     x_error_message      OUT VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        --Local Variables Declaration
        l_error_msg   VARCHAR2 (2000);
    BEGIN
        UPDATE xxdo.xxont_pick_intf_hdr_stg
           SET process_status = p_to_status, last_update_date = SYSDATE, last_updated_by = g_num_user_id,
               last_update_login = g_num_login_id
         WHERE     1 = 1
               AND process_status = p_from_status
               AND batch_number = p_batch_number;

        UPDATE xxdo.xxont_pick_intf_line_stg
           SET process_status = p_to_status, last_update_date = SYSDATE, last_updated_by = g_num_user_id,
               last_update_login = g_num_login_id
         WHERE     1 = 1
               AND process_status = p_from_status
               AND batch_number = p_batch_number;

        UPDATE xxdo.xxont_pick_intf_cmt_hdr_stg
           SET process_status = p_to_status, last_update_date = SYSDATE, last_updated_by = g_num_user_id,
               last_update_login = g_num_login_id
         WHERE     1 = 1
               AND process_status = p_from_status
               AND batch_number = p_batch_number;

        UPDATE xxdo.xxont_pick_intf_cmt_line_stg
           SET process_status = p_to_status, last_update_date = SYSDATE, last_updated_by = g_num_user_id,
               last_update_login = g_num_login_id
         WHERE     1 = 1
               AND process_status = p_from_status
               AND batch_number = p_batch_number;

        UPDATE xxdo.xxont_pick_intf_vas_hdr_stg
           SET process_status = p_to_status, last_update_date = SYSDATE, last_updated_by = g_num_user_id,
               last_update_login = g_num_login_id
         WHERE     1 = 1
               AND process_status = p_from_status
               AND batch_number = p_batch_number;

        UPDATE xxdo.xxont_pick_intf_vas_line_stg
           SET process_status = p_to_status, last_update_date = SYSDATE, last_updated_by = g_num_user_id
         WHERE     1 = 1
               AND process_status = p_from_status
               AND batch_number = p_batch_number;

        UPDATE xxdo.xxont_pick_intf_serial_stg
           SET process_status = p_to_status, last_update_date = SYSDATE, last_updated_by = g_num_user_id
         WHERE     1 = 1
               AND process_status = p_from_status
               AND batch_number = p_batch_number;

        --Begin CCR0008657
        UPDATE xxdo.xxd_ont_pk_intf_p_hdr_stg_t
           SET process_status = p_to_status, last_update_date = SYSDATE, last_updated_by = g_num_user_id
         WHERE     1 = 1
               AND process_status = p_from_status
               AND batch_number = p_batch_number;

        UPDATE xxdo.xxd_ont_pk_intf_p_ln_stg_t
           SET process_status = p_to_status, last_update_date = SYSDATE, last_updated_by = g_num_user_id
         WHERE     1 = 1
               AND process_status = p_from_status
               AND batch_number = p_batch_number;

        --End CCR0008657

        COMMIT;
        x_update_status   := g_ret_success;
        x_error_message   := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_error_msg       :=
                SUBSTR (
                       'Error in UPD_BATCH_PROCESS_STS for batch number '
                    || p_batch_number
                    || ' from status:'
                    || p_from_status
                    || ' to '
                    || p_to_status
                    || '. Error is:'
                    || SQLERRM,
                    1,
                    2000);
            x_update_status   := g_ret_error;
            x_error_message   := l_error_msg;
            ROLLBACK;
    END upd_batch_process_sts;

    --Added for change 2.0 for Regenerate XML
    /********************************************************************************
    Procedure/Function Name :   upd_pick_tkt_proc_sts (Added for change 2.0)
    Description             :   This procedure identifies the lastest delivery number
                                for the input delivery number and updates the process
                                status to 'NEW'. Used for Regenerate XML
    Parameters              :   p_order_number (Delivery ID or Pick ticket number)
    *********************************************************************************/
    PROCEDURE upd_pick_tkt_proc_sts (p_order_number IN NUMBER, x_ret_sts OUT NUMBER, x_ret_message OUT VARCHAR2)
    IS
        --Local Variables Declaration
        l_order_number     VARCHAR2 (30) := NULL; -- Changed to VARCHAR2 from NUMBER for CCR0009119
        l_header_id        NUMBER (30) := NULL;
        l_request_id       NUMBER (30) := NULL;
        l_process_status   VARCHAR2 (30) := NULL;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'In Update Pick Ticket Status procedure for Regenerate XML.');

        BEGIN
            SELECT order_number, header_id, request_id,
                   process_status
              INTO l_order_number, l_header_id, l_request_id, l_process_status
              FROM (SELECT stg.order_number, stg.header_id, stg.request_id,
                           stg.process_status, RANK () OVER (PARTITION BY stg.order_number, stg.process_status ORDER BY stg.creation_date DESC) ranking
                      FROM xxdo.xxont_pick_intf_hdr_stg stg
                     WHERE     1 = 1
                           AND stg.order_number = p_order_number
                           AND stg.process_status = gc_processed_status
                           AND stg.source_type = 'ORDER') xx
             WHERE 1 = 1 AND xx.ranking = 1;
        EXCEPTION
            WHEN TOO_MANY_ROWS
            THEN
                NULL;
            WHEN OTHERS
            THEN
                NULL;
        END;

        IF (l_order_number IS NOT NULL AND l_header_id IS NOT NULL AND l_process_status IS NOT NULL AND l_request_id IS NOT NULL)
        THEN
            UPDATE xxdo.xxont_pick_intf_hdr_stg stg
               SET stg.process_status = gc_new_status, stg.last_update_date = SYSDATE, stg.last_updated_by = g_num_user_id,
                   stg.last_update_login = g_num_login_id, stg.batch_number = NVL (stg.batch_number, xxdo.xxd_wms_hj_pick_tkt_batch_no_s.NEXTVAL)
             WHERE     1 = 1
                   AND stg.order_number = l_order_number
                   AND stg.header_id = l_header_id
                   AND stg.process_status = l_process_status
                   AND stg.request_id = l_request_id;

            UPDATE xxdo.xxont_pick_intf_line_stg stg
               SET stg.process_status = gc_new_status, stg.last_update_date = SYSDATE, stg.last_updated_by = g_num_user_id,
                   stg.last_update_login = g_num_login_id
             WHERE     1 = 1
                   AND stg.order_number = l_order_number
                   AND stg.header_id = l_header_id
                   AND stg.process_status = l_process_status
                   AND stg.request_id = l_request_id;

            UPDATE xxdo.xxont_pick_intf_cmt_hdr_stg stg
               SET stg.process_status = gc_new_status, stg.last_update_date = SYSDATE, stg.last_updated_by = g_num_user_id,
                   stg.last_update_login = g_num_login_id
             WHERE     1 = 1
                   AND stg.order_number = l_order_number
                   AND stg.process_status = l_process_status
                   AND stg.request_id = l_request_id;

            UPDATE xxdo.xxont_pick_intf_cmt_line_stg stg
               SET stg.process_status = gc_new_status, stg.last_update_date = SYSDATE, stg.last_updated_by = g_num_user_id,
                   stg.last_update_login = g_num_login_id
             WHERE     1 = 1
                   AND stg.order_number = l_order_number
                   AND stg.process_status = l_process_status
                   AND stg.request_id = l_request_id;

            UPDATE xxdo.xxont_pick_intf_vas_hdr_stg stg
               SET stg.process_status = gc_new_status, stg.last_update_date = SYSDATE, stg.last_updated_by = g_num_user_id,
                   stg.last_update_login = g_num_login_id
             WHERE     1 = 1
                   AND stg.order_number = l_order_number
                   AND stg.process_status = l_process_status
                   AND stg.request_id = l_request_id;

            UPDATE xxdo.xxont_pick_intf_vas_line_stg stg
               SET stg.process_status = gc_new_status, stg.last_update_date = SYSDATE, stg.last_updated_by = g_num_user_id
             WHERE     1 = 1
                   AND stg.order_number = l_order_number
                   AND stg.process_status = l_process_status
                   AND stg.request_id = l_request_id;

            --Begin CCR0008657
            UPDATE xxdo.xxd_ont_pk_intf_p_ln_stg_t stg
               SET stg.process_status = gc_new_status, stg.last_update_date = SYSDATE, stg.last_updated_by = g_num_user_id
             WHERE     1 = 1
                   AND stg.order_number = l_order_number
                   AND stg.process_status = l_process_status
                   AND stg.request_id = l_request_id;

            UPDATE xxdo.xxd_ont_pk_intf_p_hdr_stg_t stg
               SET stg.process_status = gc_new_status, stg.last_update_date = SYSDATE, stg.last_updated_by = g_num_user_id
             WHERE     1 = 1
                   AND stg.order_number = l_order_number
                   AND stg.process_status = l_process_status
                   AND stg.request_id = l_request_id;

            --End CCR0008657

            COMMIT;
            x_ret_sts       := g_success;
            x_ret_message   := NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_ret_sts       := g_warning;
            x_ret_message   := SUBSTR (SQLERRM, 1, 2000);
    END upd_pick_tkt_proc_sts;

    --Added for change 2.0
    --Procedure for SOA to select eligible pick ticket batches with oracle object type as out variable
    PROCEDURE pick_tkt_extract_soa_obj_type (
        p_org_code        IN     VARCHAR2,                               --4.1
        x_batch_num_tbl      OUT xxd_ebs_hj_pick_tkt_batch_tbl)
    IS
        l_proc_name       VARCHAR2 (30) := 'PICK_TKT_EXTRACT_SOA_OBJ_TYPE';
        l_err_msg         VARCHAR2 (2000) := NULL;
        l_batch_num_tbl   xxd_ebs_hj_pick_tkt_batch_tbl;
        l_update_status   VARCHAR2 (1) := 'S';
        l_error_message   VARCHAR2 (2000) := NULL;
        ln_created_by     NUMBER := -1;

        --Cursor to identify the records in inprocess in last X hours
        CURSOR inprc_cur IS
              SELECT DISTINCT stg.request_id, stg.batch_number, stg.process_status,
                              stg.warehouse_code
                FROM xxdo.xxont_pick_intf_hdr_stg stg
               WHERE     1 = 1
                     AND stg.process_status = gc_inprocess_status
                     AND stg.batch_number IS NOT NULL
                     AND stg.last_update_date <
                         (SYSDATE - NVL (gn_reprocess_hours, 3) / 24) --more than last gn_reprocess_hours or 3 hours
                     AND stg.source_type = 'ORDER'
                     AND stg.warehouse_code = p_org_code                 --4.1
            ORDER BY stg.request_id, stg.batch_number;
    BEGIN
        BEGIN
            SELECT user_id
              INTO ln_created_by
              FROM dba_users
             WHERE username = 'SOA_INT';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_created_by   := -1;
        END;

        --Identify the records stuck in INPROCESS status and update the status from INPROCESS to NEW
        FOR inprc_rec IN inprc_cur
        LOOP
            l_err_msg         := NULL;
            l_update_status   := 'S';
            l_error_message   := NULL;
            upd_batch_process_sts (
                p_batch_number    => inprc_rec.batch_number,
                p_from_status     => inprc_rec.process_status,
                p_to_status       => gc_new_status,
                x_update_status   => l_update_status,
                x_error_message   => l_error_message);

            IF l_update_status <> 'S'
            THEN
                l_err_msg   :=
                    SUBSTR (
                           'SOA_CALL. In INPRC_CUR cursor loop. Error updating process status from '
                        || gc_inprocess_status
                        || ' to '
                        || gc_new_status
                        || ' for Batch Number:'
                        || inprc_rec.batch_number
                        || ' for Warehouse:'                             --4.1
                        || inprc_rec.warehouse_code                      --4.1
                        || gc_period_char
                        || 'Error is:'
                        || l_error_message,
                        1,
                        2000);
                --Added for change 2.3 on 09Apr2019
                --Write the error message into debug table
                debug_prc (pv_application => 'EBS_HJ_PICK_TKT_SOA_CALL', pv_debug_text => l_err_msg, pv_debug_message => NULL, pn_created_by => ln_created_by, pn_session_id => SYS_CONTEXT ('USERENV', 'SESSIONID'), pn_debug_id => -1
                           , pn_request_id => -1);
            END IF;
        END LOOP;

        l_err_msg   := NULL;

        --Get the new records and assign to the out parameter
        BEGIN
            SELECT yy.*
              BULK COLLECT INTO x_batch_num_tbl
              FROM (SELECT xxd_ebs_hj_pick_tkt_batch (xx.request_id, xx.batch_number, xx.process_status)
                      FROM (  SELECT DISTINCT stg.request_id, stg.batch_number, stg.process_status
                                FROM xxdo.xxont_pick_intf_hdr_stg stg
                               WHERE     1 = 1
                                     AND stg.process_status = gc_new_status
                                     AND stg.batch_number IS NOT NULL
                                     AND stg.source_type = 'ORDER'
                                     AND stg.warehouse_code = p_org_code --4.1
                            ORDER BY stg.request_id, stg.batch_number) xx) yy;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_err_msg   :=
                    SUBSTR (
                           'SOA_CALL - Exception in query to get batch numbers and assign them to x_batch_num_tbl table type Out Variable in '
                        || gc_package_name
                        || '.'
                        || l_proc_name
                        || '. Error is: '
                        || SQLERRM,
                        1,
                        2000);
                --Added for change 2.3 on 09Apr2019
                --Write the error message into debug table
                debug_prc (pv_application => 'EBS_HJ_PICK_TKT_SOA_CALL', pv_debug_text => l_err_msg, pv_debug_message => NULL, pn_created_by => ln_created_by, pn_session_id => SYS_CONTEXT ('USERENV', 'SESSIONID'), pn_debug_id => -1
                           , pn_request_id => -1);
        END;

        --If there are records with NEW status and inserted into the x_batch_num_tbl table type
        --then update process for the batch numbers from NEW to INPROCESS
        IF x_batch_num_tbl.COUNT > 0
        THEN
            FOR i IN 1 .. x_batch_num_tbl.COUNT
            LOOP
                l_err_msg         := NULL;
                l_update_status   := 'S';
                l_error_message   := NULL;
                --Update the process status of the batch numbers from NEW to INPROCESS
                upd_batch_process_sts (
                    p_batch_number    => x_batch_num_tbl (i).batch_number,
                    p_from_status     => x_batch_num_tbl (i).process_status,
                    p_to_status       => gc_inprocess_status,
                    x_update_status   => l_update_status,
                    x_error_message   => l_error_message);
                DBMS_OUTPUT.put_line (l_update_status);

                IF l_update_status <> 'S'
                THEN
                    l_err_msg   :=
                        SUBSTR (
                               'SOA_CALL. In x_batch_num_tbl loop. Error updating process status from '
                            || gc_new_status
                            || ' to '
                            || gc_inprocess_status
                            || ' for Batch Number:'
                            || x_batch_num_tbl (i).batch_number
                            || ' for Warehouse:'                         --4.1
                            || p_org_code                                --4.1
                            || gc_period_char
                            || 'Error is:'
                            || l_error_message,
                            1,
                            2000);
                    --Added for change 2.3 on 09Apr2019
                    --Write the error message into debug table
                    debug_prc (pv_application => 'EBS_HJ_PICK_TKT_SOA_CALL', pv_debug_text => l_err_msg, pv_debug_message => NULL, pn_created_by => ln_created_by, pn_session_id => SYS_CONTEXT ('USERENV', 'SESSIONID'), pn_debug_id => -1
                               , pn_request_id => -1);
                ELSE
                    --If the process status is updated successfully for the batch number, then assign INPROCESS status to process status which is sent to SOA
                    x_batch_num_tbl (i).process_status   :=
                        gc_inprocess_status;
                END IF;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_err_msg   :=
                SUBSTR (
                       'SOA_CALL - Main Exception@'
                    || l_proc_name
                    || '. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            --Added for change 2.3 on 09Apr2019
            --Write the error message into debug table
            debug_prc (pv_application => 'EBS_HJ_PICK_TKT_SOA_CALL', pv_debug_text => l_err_msg, pv_debug_message => NULL, pn_created_by => ln_created_by, pn_session_id => SYS_CONTEXT ('USERENV', 'SESSIONID'), pn_debug_id => -1
                       , pn_request_id => -1);
    END pick_tkt_extract_soa_obj_type;

    --Added for change 2.0 --For Batching
    --Function to get total active orders count for this run for the order type
    FUNCTION get_active_orders_count (pn_request_id   IN NUMBER,
                                      pv_order_type   IN VARCHAR2)
        RETURN NUMBER
    IS
        --Local Variables Declaration
        l_func_name       VARCHAR2 (30) := 'GET_ACTIVE_ORDERS_COUNT';
        l_err_msg         VARCHAR2 (2000) := NULL;
        ln_orders_count   NUMBER := 0;
    BEGIN
        SELECT COUNT (*)
          INTO ln_orders_count
          FROM xxdo.xxont_pick_intf_hdr_stg stg
         WHERE     1 = 1
               AND stg.batch_number IS NULL
               AND stg.order_type = pv_order_type
               AND stg.process_status = gc_new_status
               AND stg.request_id = pn_request_id
               AND stg.source_type = 'ORDER';

        RETURN ln_orders_count;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_err_msg   :=
                SUBSTR (
                       'Exception@'
                    || l_func_name
                    || '. Returning ZERO for active orders count. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            msg (l_err_msg);
            RETURN 0;
    END get_active_orders_count;

    --Added for change 2.0 --For Batching
    --Function to return number of orders per batch for the order type passed
    FUNCTION get_orders_per_batch (pv_order_type IN VARCHAR2)
        RETURN NUMBER
    IS
        --Local Variables Declaration
        l_func_name           VARCHAR2 (30) := 'GET_ORDERS_PER_BATCH';
        l_err_msg             VARCHAR2 (2000) := NULL;
        ln_orders_per_batch   NUMBER := 0;
    BEGIN
        SELECT TO_NUMBER (flv.attribute2) orders_per_batch
          INTO ln_orders_per_batch
          FROM fnd_lookup_values_vl flv
         WHERE     1 = 1
               AND flv.lookup_type = 'XXD_WMS_HJ_BATCH'
               AND flv.enabled_flag = 'Y'
               AND flv.attribute1 = pv_order_type             ---Sales Channel
               AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE)
                               AND NVL (flv.end_date_active, SYSDATE + 1);

        RETURN ln_orders_per_batch;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF pv_order_type IN ('ECOM', 'DROPSHIP')
            THEN
                l_err_msg   :=
                    SUBSTR (
                           'Exception@'
                        || l_func_name
                        || '. Returning 100 for orders per batch for '
                        || pv_order_type
                        || ' Channel. Error is: '
                        || SQLERRM,
                        1,
                        2000);
                msg (l_err_msg);
                RETURN 100; --In case of any issue, Return 100 for order per batch
            ELSE
                l_err_msg   :=
                    SUBSTR (
                           'Exception@'
                        || l_func_name
                        || '. Returning 10 for orders per batch for '
                        || pv_order_type
                        || ' Channel. Error is: '
                        || SQLERRM,
                        1,
                        2000);
                msg (l_err_msg);
                RETURN 10; --Wholesale and Retail, return 10 for orders per batch
            END IF;
    END get_orders_per_batch;

    --Added for change 2.0 --For Batching
    --Function to return number of lines per batch for the order type passed from the lookup (XXD_WMS_HJ_BATCH)
    FUNCTION get_lines_per_batch (pv_order_type IN VARCHAR2)
        RETURN NUMBER
    IS
        --Local Variables Declaration
        l_func_name          VARCHAR2 (30) := 'GET_LINES_PER_BATCH';
        l_err_msg            VARCHAR2 (2000) := NULL;
        ln_lines_per_batch   NUMBER := 0;
    BEGIN
        SELECT TO_NUMBER (flv.attribute3) lines_per_batch
          INTO ln_lines_per_batch
          FROM fnd_lookup_values_vl flv
         WHERE     1 = 1
               AND flv.lookup_type = 'XXD_WMS_HJ_BATCH'
               AND flv.enabled_flag = 'Y'
               AND flv.attribute1 = pv_order_type             ---Sales Channel
               AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE)
                               AND NVL (flv.end_date_active, SYSDATE + 1);

        RETURN ln_lines_per_batch;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_err_msg   :=
                SUBSTR (
                       'Exception@'
                    || l_func_name
                    || '. Returning 1000 for Lines per batch. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            msg (l_err_msg);
            RETURN 1000;                    --In case of any issue Return 1000
    END get_lines_per_batch;

    --Added for change 2.0 --For Batching
    --This procedure picks up the batch number from the Pick Interface Header table and updates the batch number in all the staging tables
    PROCEDURE proc_upd_batch_num_child (pn_request_id IN NUMBER, pv_order_type IN VARCHAR2, x_update_status OUT NUMBER
                                        , x_error_message OUT VARCHAR2)
    IS
        --Local Variables Declaration
        l_proc_name   VARCHAR2 (30) := 'PROC_UPD_BATCH_NUM_CHILD';
        l_error_msg   VARCHAR2 (2000) := NULL;

        --Cursor to get Batch Number, Order Number for the request ID, Order type(Sales Channel) with process status as NEW
        CURSOR batch_num_cur IS
            SELECT DISTINCT pih.batch_number, pih.order_number, pih.request_id,
                            pih.process_status
              FROM xxdo.xxont_pick_intf_hdr_stg pih
             WHERE     1 = 1
                   AND pih.request_id = pn_request_id
                   AND pih.order_type = pv_order_type
                   AND pih.process_status = gc_new_status
                   AND pih.batch_number IS NOT NULL
                   AND pih.source_type = 'ORDER';
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'Start of Updating batch number in all staging tables based on pick int header table batch number'
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

        FOR batch_num_rec IN batch_num_cur
        LOOP
            UPDATE /*+ USE_INDEX */
                   xxdo.xxont_pick_intf_line_stg
               SET batch_number = batch_num_rec.batch_number, last_update_date = SYSDATE, last_updated_by = g_num_user_id,
                   last_update_login = g_num_login_id
             WHERE     1 = 1
                   AND process_status = batch_num_rec.process_status
                   AND request_id = batch_num_rec.request_id
                   AND order_number = batch_num_rec.order_number;

            UPDATE /*+ USE_INDEX */
                   xxdo.xxont_pick_intf_cmt_hdr_stg
               SET batch_number = batch_num_rec.batch_number, last_update_date = SYSDATE, last_updated_by = g_num_user_id,
                   last_update_login = g_num_login_id
             WHERE     1 = 1
                   AND process_status = batch_num_rec.process_status
                   AND request_id = batch_num_rec.request_id
                   AND order_number = batch_num_rec.order_number;

            UPDATE /*+ USE_INDEX */
                   xxdo.xxont_pick_intf_cmt_line_stg
               SET batch_number = batch_num_rec.batch_number, last_update_date = SYSDATE, last_updated_by = g_num_user_id,
                   last_update_login = g_num_login_id
             WHERE     1 = 1
                   AND process_status = batch_num_rec.process_status
                   AND request_id = batch_num_rec.request_id
                   AND order_number = batch_num_rec.order_number;

            UPDATE /*+ USE_INDEX */
                   xxdo.xxont_pick_intf_vas_hdr_stg
               SET batch_number = batch_num_rec.batch_number, last_update_date = SYSDATE, last_updated_by = g_num_user_id,
                   last_update_login = g_num_login_id
             WHERE     1 = 1
                   AND process_status = batch_num_rec.process_status
                   AND request_id = batch_num_rec.request_id
                   AND order_number = batch_num_rec.order_number;

            UPDATE /*+ USE_INDEX */
                   xxdo.xxont_pick_intf_vas_line_stg
               SET batch_number = batch_num_rec.batch_number, last_update_date = SYSDATE, last_updated_by = g_num_user_id
             WHERE     1 = 1
                   AND process_status = batch_num_rec.process_status
                   AND request_id = batch_num_rec.request_id
                   AND order_number = batch_num_rec.order_number;

            UPDATE /*+ USE_INDEX */
                   xxdo.xxont_pick_intf_serial_stg
               SET batch_number = batch_num_rec.batch_number, last_update_date = SYSDATE, last_updated_by = g_num_user_id
             WHERE     1 = 1
                   AND process_status = batch_num_rec.process_status
                   AND request_id = batch_num_rec.request_id
                   AND order_number = batch_num_rec.order_number;

            --Begin CCR0008657
            UPDATE /*+ USE_INDEX */
                   xxdo.xxd_ont_pk_intf_p_hdr_stg_t
               SET batch_number = batch_num_rec.batch_number, last_update_date = SYSDATE, last_updated_by = g_num_user_id
             WHERE     1 = 1
                   AND process_status = batch_num_rec.process_status
                   AND request_id = batch_num_rec.request_id
                   AND order_number = batch_num_rec.order_number;

            UPDATE /*+ USE_INDEX */
                   xxdo.xxd_ont_pk_intf_p_ln_stg_t
               SET batch_number = batch_num_rec.batch_number, last_update_date = SYSDATE, last_updated_by = g_num_user_id
             WHERE     1 = 1
                   AND process_status = batch_num_rec.process_status
                   AND request_id = batch_num_rec.request_id
                   AND order_number = batch_num_rec.order_number;
        --End CCR0008657
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
               'End of Updating batch number in all staging tables based on pick int header table batch number'
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        --COMMIT; --Commented for change 2.3 to commit all batch number updates at the end and only once on 08Apr2019
        x_update_status   := g_success;
        x_error_message   := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_error_msg       :=
                SUBSTR (
                    'Error @proc_upd_batch_num_child. Error is: ' || SQLERRM,
                    1,
                    2000);
            fnd_file.put_line (fnd_file.LOG, l_error_msg);
            x_update_status   := g_error;
            x_error_message   := l_error_msg;
            ROLLBACK;
            msg (l_error_msg);
    END proc_upd_batch_num_child;

    --Added for change 2.0 --For Batching
    ---Procedure to update the batch number for the leftover records(One batch per one header record)
    PROCEDURE proc_upd_batch_leftover (pn_request_id     IN     NUMBER,
                                       pv_order_type     IN     VARCHAR2,
                                       pn_no_of_orders   IN     NUMBER,
                                       x_update_status      OUT NUMBER, --Added out variables for change 2.3
                                       x_error_message      OUT VARCHAR2) --Added out variables for change 2.3
    IS
        --Local Variables Declaration
        l_proc_name        VARCHAR2 (30) := 'PROC_UPD_BATCH_LEFTOVER';
        l_err_msg          VARCHAR2 (2000) := NULL;
        ln_valid_rec_cnt   NUMBER := 0;
        ln_mod_count       NUMBER := 0;
        ln_batch_number    NUMBER := 0;
        ln_no_of_orders    NUMBER := 0;

        TYPE hdr_batch_id_t IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        ln_hdr_batch_id    hdr_batch_id_t;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;
    BEGIN
        msg (
            'Calling Procedure which assign a child process for each order ');

        SELECT COUNT (DISTINCT header_id)
          INTO ln_valid_rec_cnt
          FROM xxdo.xxont_pick_intf_hdr_stg
         WHERE     1 = 1
               AND batch_number IS NULL
               AND process_status = gc_new_status
               AND request_id = pn_request_id
               AND order_type = pv_order_type
               AND source_type = 'ORDER';

        --Loop for all orders that are not updated with batch number
        FOR i IN 1 .. pn_no_of_orders
        LOOP
            BEGIN
                SELECT xxdo.xxd_wms_hj_pick_tkt_batch_no_s.NEXTVAL
                  INTO ln_hdr_batch_id (i)
                  FROM DUAL;
            --msg('ln_hdr_batch_id(i) := ' || ln_hdr_batch_id(i));
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_hdr_batch_id (i + 1)   := ln_hdr_batch_id (i) + 1;
            END;

            msg (' ln_valid_rec_cnt := ' || ln_valid_rec_cnt);
            msg (
                   ' Ceil( ln_valid_rec_cnt/pn_no_of_orders) := '
                || CEIL (ln_valid_rec_cnt / pn_no_of_orders));

            UPDATE xxdo.xxont_pick_intf_hdr_stg pih
               SET batch_number   = ln_hdr_batch_id (i)
             WHERE     1 = 1
                   AND pih.header_id IN
                           (SELECT header_id
                              FROM (  SELECT DISTINCT pih_1.header_id
                                        FROM xxdo.xxont_pick_intf_hdr_stg pih_1
                                       WHERE     1 = 1
                                             AND pih_1.batch_number IS NULL
                                             AND pih_1.process_status =
                                                 gc_new_status
                                             AND pih_1.request_id =
                                                 pn_request_id
                                             AND pih_1.order_type =
                                                 pv_order_type
                                             AND pih_1.source_type = 'ORDER'
                                    ORDER BY 1)
                             WHERE     1 = 1
                                   AND ROWNUM <=
                                       CEIL (
                                           ln_valid_rec_cnt / pn_no_of_orders))
                   AND pih.batch_number IS NULL
                   AND pih.process_status = gc_new_status
                   AND pih.request_id = pn_request_id
                   AND pih.order_type = pv_order_type
                   AND pih.source_type = 'ORDER';
        END LOOP;
    --COMMIT; --Commented for change 2.3 to commit all batch number updates at the end and only once on 08Apr2019
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;                      --Added for change 2.3 on 17Apr2019
            l_err_msg   :=
                SUBSTR (
                       'Exception while updating batch number for each order for '
                    || pv_order_type
                    || ' Channel in '
                    || l_proc_name
                    || ' Error is: '
                    || SQLERRM,
                    1,
                    2000);
            msg (l_err_msg);
    END proc_upd_batch_leftover;

    --Added for change 2.0 --For Batching
    --Procedure to update batch_number in Pick interface Headers table
    PROCEDURE proc_update_batch (pn_request_id IN NUMBER, pv_order_type IN VARCHAR2, x_update_status OUT NUMBER
                                 , x_error_message OUT VARCHAR2)
    IS
        --Local Variables Declaration
        l_proc_name           VARCHAR2 (30) := 'PROC_UPDATE_BATCH';
        l_err_msg             VARCHAR2 (2000) := NULL;
        ln_orders_count       NUMBER := 0;
        ln_lines_count        NUMBER := 0;
        ln_count              NUMBER := 0;
        ln_mod_count          NUMBER := 0;
        ln_batch_number       NUMBER := 0;
        ln_orders_per_batch   NUMBER := 0;
        ln_lines_per_batch    NUMBER := 0;
        l_update_status       NUMBER := g_success;
        l_error_message       VARCHAR2 (2000) := NULL;
        l_upd_sts_leftover    NUMBER := g_success;
        --Added for change 2.3
        l_err_msg_leftover    VARCHAR2 (2000) := NULL;  --Added for change 2.3
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Call Procedure proc_update_batch.');
        ln_orders_per_batch   := get_orders_per_batch (pv_order_type);
        --Get count of orders for this sales channel for the request id
        ln_orders_count       :=
            get_active_orders_count (pn_request_id, pv_order_type);

        IF pv_order_type IN ('ECOM', 'DROPSHIP')
        THEN
            ln_mod_count   := CEIL (ln_orders_count / ln_orders_per_batch);

            FOR i IN 1 .. ln_mod_count
            LOOP
                BEGIN
                    --Getting batch number from sequence
                    ln_batch_number   :=
                        xxdo.xxd_wms_hj_pick_tkt_batch_no_s.NEXTVAL;

                    --Updating the pick int header staging table batch number for a group of orders where count of all orders is less than or equal to orders per batch(ln_orders_per_batch)
                    UPDATE xxont_pick_intf_hdr_stg
                       SET batch_number   = ln_batch_number
                     WHERE     1 = 1
                           AND header_id IN
                                   (SELECT header_id
                                      FROM (  SELECT header_id, SUM (COUNT (1)) OVER (ORDER BY COUNT (1), header_id) cntt
                                                --Get the cumulative sum of pick tickets
                                                FROM xxdo.xxont_pick_intf_hdr_stg
                                               WHERE     1 = 1
                                                     AND batch_number IS NULL
                                                     AND order_type =
                                                         pv_order_type
                                                     AND process_status =
                                                         gc_new_status
                                                     AND request_id =
                                                         pn_request_id
                                                     AND source_type = 'ORDER'
                                            GROUP BY header_id
                                            ORDER BY 2)
                                     WHERE     1 = 1
                                           AND cntt <= ln_orders_per_batch)
                           AND batch_number IS NULL
                           AND order_type = pv_order_type
                           AND process_status = gc_new_status
                           AND request_id = pn_request_id
                           AND source_type = 'ORDER';

                    ln_count   := SQL%ROWCOUNT;
                    l_err_msg   :=
                        SUBSTR (
                               'Completed updating Batch Number in XXONT_PICK_INTF_HDR_STG table for '
                            || pv_order_type
                            || ' Channel.  Number of orders updated = '
                            || ln_count,
                            1,
                            2000);
                    msg (l_err_msg);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_err_msg   :=
                            SUBSTR (
                                   'Error while updating batch number for sales channel/order type - '
                                || pv_order_type
                                || ' is '
                                || SQLERRM,
                                1,
                                2000);
                        msg (l_err_msg);
                END;
            END LOOP;
        ELSE                                 --Wholesale or Retail order types
            --Get lines per batch for the sales channel
            ln_lines_per_batch   := get_lines_per_batch (pv_order_type);
            ln_mod_count         :=
                CEIL (ln_orders_count / ln_orders_per_batch);

            FOR j IN 1 .. ln_mod_count
            LOOP
                BEGIN
                    --Getting batch number from sequence
                    ln_batch_number   :=
                        xxdo.xxd_wms_hj_pick_tkt_batch_no_s.NEXTVAL;

                    --Updating the pick int Header staging table batch number for a group of orders where count of all lines is less than or equal to lines per batch(ln_no_of_lines)
                    UPDATE xxdo.xxont_pick_intf_hdr_stg pih
                       SET pih.batch_number   = ln_batch_number
                     WHERE     1 = 1
                           AND header_id IN
                                   (SELECT header_id
                                      FROM (  SELECT header_id, SUM (COUNT (1)) OVER (ORDER BY COUNT (1), header_id) cntt, --Get the cumulative sum of pick tickets
                                                                                                                           DENSE_RANK () OVER (ORDER BY COUNT (1), header_id) ranking
                                                --Get the ranking for the Pick Tickets
                                                FROM xxdo.xxont_pick_intf_line_stg pil
                                               WHERE     1 = 1
                                                     --AND pil.batch_number IS NULL
                                                     AND pil.process_status =
                                                         gc_new_status
                                                     AND pil.request_id =
                                                         pn_request_id
                                                     ---Get the orders or pick tickets for the order type passed as parameter
                                                     AND pil.header_id IN
                                                             (SELECT header_id
                                                                FROM xxdo.xxont_pick_intf_hdr_stg
                                                               WHERE     1 = 1
                                                                     AND batch_number
                                                                             IS NULL
                                                                     AND order_type =
                                                                         pv_order_type
                                                                     AND process_status =
                                                                         gc_new_status
                                                                     AND request_id =
                                                                         pn_request_id)
                                            GROUP BY pil.header_id
                                            ORDER BY 2)
                                     WHERE     1 = 1
                                           AND cntt <= ln_lines_per_batch
                                           AND ranking <= ln_orders_per_batch)
                           AND pih.process_status = gc_new_status
                           AND pih.batch_number IS NULL
                           AND pih.request_id = pn_request_id
                           AND pih.order_type = pv_order_type;

                    ln_count   := SQL%ROWCOUNT;
                    l_err_msg   :=
                        SUBSTR (
                               'Completed updating Batch Number in XXONT_PICK_INTF_HDR_STG table for '
                            || pv_order_type
                            || ' Channel. Number of orders updated = '
                            || ln_count,
                            1,
                            2000);
                    msg (l_err_msg);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_err_msg   :=
                            SUBSTR (
                                   'Error in Updating the batch number in pick ticket header table for order type/ sales channel '
                                || pv_order_type
                                || '. Error is '
                                || SQLERRM,
                                1,
                                2000);
                        msg (l_err_msg);
                END;
            END LOOP;
        END IF;

        --COMMIT; --Commented for change 2.3 to commit all batch number updates only once and at the end on 08Apr2019
        ln_count              := 0;

        --Get the count distinct orders/pick tickets where line count is greater than lines_per_batch(ln_no_of_lines)
        --Getting the count of remaining orders where the batch_number is not updated.
        BEGIN
            SELECT COUNT (DISTINCT header_id)
              INTO ln_count
              FROM xxdo.xxont_pick_intf_hdr_stg
             WHERE     1 = 1
                   AND batch_number IS NULL
                   AND process_status = gc_new_status
                   AND request_id = pn_request_id
                   AND order_type = pv_order_type;
        END;

        --If there are orders where line count is greater than lines per batch then call proc_upd_batch_leftover procedure
        IF ln_count > 0
        THEN
            proc_upd_batch_leftover (pn_request_id     => pn_request_id,
                                     pv_order_type     => pv_order_type,
                                     pn_no_of_orders   => ln_count,
                                     x_update_status   => l_upd_sts_leftover,
                                     --Added out variables for change 2.3
                                     x_error_message   => l_err_msg_leftover --Added out variables for change 2.3
                                                                            );
        END IF;

        --Now call the procedure to update the batch number in all the staging tables
        proc_upd_batch_num_child (pn_request_id => pn_request_id, pv_order_type => pv_order_type, x_update_status => l_update_status
                                  , x_error_message => l_error_message);

        IF l_update_status <> g_success OR l_upd_sts_leftover <> g_success --Added OR conditon for change 2.3
        THEN
            x_update_status   := g_warning;
            x_error_message   := NVL (l_err_msg_leftover, l_error_message);
            ROLLBACK;
        --Added for change 2.3 to rollback batch number updates if the child records are not updated
        ELSE
            l_err_msg   :=
                SUBSTR (
                       'Completed updating Batch Number in all the Pick Ticket interface tables for order type/ sales channel = '
                    || pv_order_type,
                    1,
                    2000);
            msg (l_err_msg);
            COMMIT;
        --Added for change 2.3 to commit all batch number updates once and at the end on 08Apr2019
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            --Added for change 2.3 to rollback if there is any exception
            l_error_message   :=
                SUBSTR ('Error@proc_update_batch. Error is:' || SQLERRM,
                        1,
                        2000);
            msg (l_error_message);
            x_update_status   := g_warning;
            x_error_message   := l_error_message;
    END proc_update_batch;

    --Added get_sales_channel function for change 2.1 to improve performance
    FUNCTION get_sales_channel (pn_order_header_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_func_name       VARCHAR2 (30) := 'GET_SALES_CHANNEL';
        lv_sales_channel   VARCHAR2 (30) := NULL;
    BEGIN
        SELECT DECODE (oos.NAME,  'Flagstaff', 'ECOMM',  'Retail', 'RETAIL',  DECODE (ottt.NAME,  'Consumer Direct - US', 'DROP-SHIP',  '3rd Party eCommerce - US', 'DROP-SHIP', --Added as per ver 2.6
                                                                                                                                                                                  'WHOLESALE')) customer_type
          INTO lv_sales_channel
          FROM apps.oe_order_sources oos, apps.oe_order_headers_all ooha, apps.oe_transaction_types_tl ottt
         WHERE     1 = 1
               AND ooha.header_id = pn_order_header_id
               AND ooha.order_source_id = oos.order_source_id
               AND ottt.transaction_type_id = ooha.order_type_id
               AND ottt.LANGUAGE = USERENV ('LANG');

        RETURN lv_sales_channel;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_sales_channel   := NULL;
            RETURN lv_sales_channel;
    END get_sales_channel;

    /****************************************************************************
    -- Procedure Name   :   purge_stg_data
    -- Description      :   This procedure is to purge the old data that is in OBSOLETE status from staging tabel
    -- Parameters       :   p_in_num_purge_days IN :
    -- Return/Exit      :   None
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date         Author              Version Description
    -- ----------   ------------------  ------- ---------------------------------
    -- 02/24/2019   Kranthi Bollam      2.3     CCR0007774 - Purge OBSOLETE Data in staging table
    ***************************************************************************/
    PROCEDURE purge_stg_data (p_in_num_purge_days IN NUMBER)
    IS
        l_dte_sysdate   DATE := SYSDATE;
    BEGIN
        msg (
               'In EBS to HJ integration Staging tables purge program(PURGE_STG_DATA) - START. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        fnd_file.put_line (fnd_file.LOG, 'Parameters.');
        fnd_file.put_line (fnd_file.LOG, '----------------------');
        fnd_file.put_line (fnd_file.LOG,
                           'Purge Days:' || p_in_num_purge_days);
        fnd_file.put_line (fnd_file.LOG, '----------------------');
        fnd_file.put_line (
            fnd_file.LOG,
            'Purging ' || p_in_num_purge_days || ' days old records...');

        /*Pick Ticket header interface*/
        BEGIN
            DELETE FROM
                xxdo.xxont_pick_intf_hdr_stg
                  WHERE     process_status = gc_obsolete_status
                        AND creation_date <
                            l_dte_sysdate - p_in_num_purge_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Error happened while purging shipment headers data: '
                    || SQLERRM);
        END;

        /*Pick Ticket line interface*/
        BEGIN
            DELETE FROM
                xxdo.xxont_pick_intf_line_stg
                  WHERE     process_status = gc_obsolete_status
                        AND creation_date <
                            l_dte_sysdate - p_in_num_purge_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Error happened while purging Pick Ticket Line Data '
                    || SQLERRM);
        END;

        /*Pick Ticket comment header interface*/
        BEGIN
            DELETE FROM
                xxdo.xxont_pick_intf_cmt_hdr_stg
                  WHERE     process_status = gc_obsolete_status
                        AND creation_date <
                            l_dte_sysdate - p_in_num_purge_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Error happened while purging Pick Ticket Comment Header Data '
                    || SQLERRM);
        END;

        /*Pick Ticket comment line interface*/
        BEGIN
            DELETE FROM
                xxdo.xxont_pick_intf_cmt_line_stg
                  WHERE     process_status = gc_obsolete_status
                        AND creation_date <
                            l_dte_sysdate - p_in_num_purge_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Error happened while purging Pick Ticket Comment Line Data '
                    || SQLERRM);
        END;

        /*Pick Ticket vas header interface*/
        BEGIN
            DELETE FROM
                xxdo.xxont_pick_intf_vas_hdr_stg
                  WHERE     process_status = gc_obsolete_status
                        AND creation_date <
                            l_dte_sysdate - p_in_num_purge_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Error happened while purging Pick Ticket Vas Header Data '
                    || SQLERRM);
        END;

        /*Pick Ticket vas line interface*/
        BEGIN
            DELETE FROM
                xxdo.xxont_pick_intf_vas_line_stg
                  WHERE     process_status = gc_obsolete_status
                        AND creation_date <
                            l_dte_sysdate - p_in_num_purge_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Error happened while purging Pick Ticket VAS Line Data '
                    || SQLERRM);
        END;

        msg (
               'In EBS to HJ integration Staging tables purge program(PURGE_STG_DATA) - END. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexepected error while purging the records' || SQLERRM);
    END purge_stg_data;

    /****************************************************************************
    -- Procedure Name   :   purge_log_data
    -- Description      :   This procedure is to purge the old data that is in PROCESSED status from log tabel
    -- Parameters       :   p_in_num_purge_days IN :
    -- Return/Exit      :   None
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date         Author              Version Description
    -- ----------   ------------------  ------- ---------------------------------
    -- 02/24/2019   Kranthi Bollam      2.3     CCR0007774 - Purge OBSOLETE Data in staging table
    ***************************************************************************/
    PROCEDURE purge_log_data (p_in_num_purge_log_days IN NUMBER)
    IS
        l_dte_sysdate   DATE := SYSDATE;
    BEGIN
        msg (
               'In EBS to HJ integration Log tables purge program(PURGE_LOG_DATA) - START. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        fnd_file.put_line (fnd_file.LOG, 'Parameters.');
        fnd_file.put_line (fnd_file.LOG, '----------------------');
        fnd_file.put_line (fnd_file.LOG,
                           'Purge Days:' || p_in_num_purge_log_days);
        fnd_file.put_line (fnd_file.LOG, '----------------------');
        fnd_file.put_line (
            fnd_file.LOG,
            'Purging ' || p_in_num_purge_log_days || ' days old records...');

        /*Pick Ticket header interface*/
        BEGIN
            DELETE FROM
                xxdo.xxont_pick_intf_hdr_stg_log
                  WHERE     process_status = gc_processed_status
                        AND creation_date <
                            l_dte_sysdate - p_in_num_purge_log_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Error happened while purging shipment headers Log data: '
                    || SQLERRM);
        END;

        /*Pick Ticket line interface*/
        BEGIN
            DELETE FROM
                xxdo.xxont_pick_intf_line_stg_log
                  WHERE     process_status = gc_processed_status
                        AND creation_date <
                            l_dte_sysdate - p_in_num_purge_log_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Error happened while purging Pick Ticket Line Log Data '
                    || SQLERRM);
        END;

        /*Pick Ticket comment header interface*/
        BEGIN
            DELETE FROM
                xxdo.xxont_pick_intf_cmt_hdr_s_log
                  WHERE     process_status = gc_processed_status
                        AND creation_date <
                            l_dte_sysdate - p_in_num_purge_log_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Error happened while purging Pick Ticket Comment Header Log Data '
                    || SQLERRM);
        END;

        /*Pick Ticket comment line interface*/
        BEGIN
            DELETE FROM
                xxdo.xxont_pick_intf_cmt_line_s_log
                  WHERE     process_status = gc_processed_status
                        AND creation_date <
                            l_dte_sysdate - p_in_num_purge_log_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Error happened while purging Pick Ticket Comment Line Log Data '
                    || SQLERRM);
        END;

        /*Pick Ticket vas header interface*/
        BEGIN
            DELETE FROM
                xxdo.xxont_pick_intf_vas_hdr_s_log
                  WHERE     process_status = gc_processed_status
                        AND creation_date <
                            l_dte_sysdate - p_in_num_purge_log_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Error happened while purging Pick Ticket Vas Header Log Data '
                    || SQLERRM);
        END;

        /*Pick Ticket vas line interface*/
        BEGIN
            DELETE FROM
                xxdo.xxont_pick_intf_vas_line_s_log
                  WHERE     process_status = gc_processed_status
                        AND creation_date <
                            l_dte_sysdate - p_in_num_purge_log_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Error happened while purging Pick Ticket VAS Line Log Data '
                    || SQLERRM);
        END;

        msg (
               'In EBS to HJ integration Log tables purge program(PURGE_LOG_DATA) - END. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexepected error while purging the Log table records'
                || SQLERRM);
    END purge_log_data;

    /****************************************************************************
    -- Procedure Name   :   archive_stg_data
    -- Description      :   This procedure is to archive the old data that is in PROCESSED status from staging tabel
    -- Parameters       :   None
    -- Return/Exit      :   None
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date         Author              Version Description
    -- ----------   ------------------  ------- ---------------------------------
    -- 02/24/2019   Kranthi Bollam      2.3     CCR0007774 - Purge OBSOLETE Data in staging table
    ***************************************************************************/
    PROCEDURE archive_stg_data
    IS
        CURSOR cur_closed_delivery IS
            SELECT stg.order_number
              FROM xxdo.xxont_pick_intf_hdr_stg stg, apps.wsh_new_deliveries wnd
             WHERE     stg.order_number = wnd.delivery_id
                   AND wnd.status_code = 'CL'
                   AND wnd.organization_id = 107
                   AND stg.process_status = 'PROCESSED';

        l_dte_sysdate   DATE := SYSDATE;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'EBS to HJ integration tables archive program started.');

        FOR rec_delivery IN cur_closed_delivery
        LOOP
            /*Pick Ticket header interface*/
            BEGIN
                INSERT INTO xxdo.xxont_pick_intf_hdr_stg_log (
                                warehouse_code,
                                order_number,
                                website_code,
                                customer_language,
                                freight_amount,
                                host_order_number,
                                custom_cartonization_required,
                                priority,
                                vendor_number,
                                bill_frght_to_phone,
                                bill_frght_to_country_code,
                                bill_frght_to_zip,
                                bill_frght_to_state,
                                bill_frght_to_city,
                                bill_frght_to_addr3,
                                bill_frght_to_addr2,
                                bill_frght_to_addr1,
                                bill_frght_to_name,
                                freight_account_number,
                                freight_terms,
                                insurance_amount,
                                latest_ship_date,
                                earliest_ship_date,
                                order_date,
                                buying_unit,
                                department_name,
                                department_code,
                                cust_po_number,
                                dc_number,
                                store_order_number,
                                store_number,
                                bill_to_email,
                                bill_to_phone,
                                bill_to_country_code,
                                bill_to_zip,
                                bill_to_state,
                                bill_to_city,
                                bill_to_addr3,
                                bill_to_addr2,
                                bill_to_addr1,
                                bill_to_attention,
                                bill_to_name,
                                bill_to_code,
                                ship_to_vat_number,
                                ship_to_email,
                                ship_to_residential_flag,
                                ship_to_phone,
                                ship_to_country_code,
                                ship_to_zip,
                                ship_to_state,
                                ship_to_city,
                                ship_to_addr3,
                                ship_to_addr2,
                                ship_to_addr1,
                                ship_to_attention,
                                ship_to_name,
                                ship_to_code,
                                return_phone,
                                return_country_code,
                                return_zip,
                                return_state,
                                return_city,
                                return_addr3,
                                return_addr2,
                                return_addr1,
                                return_attention,
                                return_name,
                                return_code,
                                carrier_name,
                                service_level,
                                carrier,
                                customer_category,
                                status,
                                customer_name,
                                customer_code,
                                brand_code,
                                company,
                                order_type,
                                dropship_customer_name,
                                dropship_contact_text,
                                ecomm_usps_data,
                                ecomm_newgistics_data,
                                ecomm_website_url,
                                ecomm_website_phone,
                                auto_receipt_flag,
                                saturday_delivery_flag,
                                charge_service_level,
                                duty_account_number,
                                duty_terms,
                                store_name,
                                header_id,
                                record_type,
                                destination,
                                SOURCE,
                                attribute20,
                                attribute19,
                                attribute18,
                                attribute17,
                                attribute16,
                                attribute15,
                                attribute14,
                                attribute13,
                                attribute12,
                                attribute11,
                                attribute10,
                                attribute9,
                                attribute8,
                                attribute7,
                                attribute6,
                                attribute5,
                                attribute4,
                                attribute3,
                                attribute2,
                                attribute1,
                                source_type,
                                last_update_login,
                                last_updated_by,
                                last_update_date,
                                created_by,
                                creation_date,
                                request_id,
                                error_message,
                                process_status,
                                archive_date,
                                archive_request_id,
                                return_source,
                                prepick_date,
                                batch_number,
                                -- Added for Change 3.0
                                customer_contact_phone,
                                customer_email,
                                customer_payment_method,
                                customer_reward_number,
                                total_merchandise_value,
                                total_rewards_value,
                                total_promo_value,
                                total_shipping_charges,
                                total_shipping_discount,
                                total_tax,
                                total_charge,
                                total_savings,
                                order_by_name,
                                order_by_address1,
                                order_by_address2,
                                order_by_address3,
                                order_by_city,
                                order_by_state,
                                order_by_country_code,
                                order_by_zipcode          -- End of Change 3.0
                                                )
                    SELECT warehouse_code, order_number, website_code,
                           customer_language, freight_amount, host_order_number,
                           custom_cartonization_required, priority, vendor_number,
                           bill_frght_to_phone, bill_frght_to_country_code, bill_frght_to_zip,
                           bill_frght_to_state, bill_frght_to_city, bill_frght_to_addr3,
                           bill_frght_to_addr2, bill_frght_to_addr1, bill_frght_to_name,
                           freight_account_number, freight_terms, insurance_amount,
                           latest_ship_date, earliest_ship_date, order_date,
                           buying_unit, department_name, department_code,
                           cust_po_number, dc_number, store_order_number,
                           store_number, bill_to_email, bill_to_phone,
                           bill_to_country_code, bill_to_zip, bill_to_state,
                           bill_to_city, bill_to_addr3, bill_to_addr2,
                           bill_to_addr1, bill_to_attention, bill_to_name,
                           bill_to_code, ship_to_vat_number, ship_to_email,
                           ship_to_residential_flag, ship_to_phone, ship_to_country_code,
                           ship_to_zip, ship_to_state, ship_to_city,
                           ship_to_addr3, ship_to_addr2, ship_to_addr1,
                           ship_to_attention, ship_to_name, ship_to_code,
                           return_phone, return_country_code, return_zip,
                           return_state, return_city, return_addr3,
                           return_addr2, return_addr1, return_attention,
                           return_name, return_code, carrier_name,
                           service_level, carrier, customer_category,
                           status, customer_name, customer_code,
                           brand_code, company, order_type,
                           dropship_customer_name, dropship_contact_text, ecomm_usps_data,
                           ecomm_newgistics_data, ecomm_website_url, ecomm_website_phone,
                           auto_receipt_flag, saturday_delivery_flag, charge_service_level,
                           duty_account_number, duty_terms, store_name,
                           header_id, record_type, destination,
                           SOURCE, attribute20, attribute19,
                           attribute18, attribute17, attribute16,
                           attribute15, attribute14, attribute13,
                           attribute12, attribute11, attribute10,
                           attribute9, attribute8, attribute7,
                           attribute6, attribute5, attribute4,
                           attribute3, attribute2, attribute1,
                           source_type, last_update_login, last_updated_by,
                           last_update_date, created_by, creation_date,
                           request_id, error_message, process_status,
                           l_dte_sysdate, g_num_request_id, return_source,
                           prepick_date, batch_number, -- Start of Change 3.0
                                                       customer_contact_phone,
                           customer_email, customer_payment_method, customer_reward_number,
                           total_merchandise_value, total_rewards_value, total_promo_value,
                           total_shipping_charges, total_shipping_discount, total_tax,
                           total_charge, total_savings, order_by_name,
                           order_by_address1, order_by_address2, order_by_address3,
                           order_by_city, order_by_state, order_by_country_code,
                           order_by_zipcode
                      -- End of Change 3.0
                      FROM xxdo.xxont_pick_intf_hdr_stg
                     WHERE     process_status = gc_processed_status
                           AND order_number = rec_delivery.order_number;

                DELETE FROM
                    xxdo.xxont_pick_intf_hdr_stg
                      WHERE     process_status = gc_processed_status
                            AND order_number = rec_delivery.order_number;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg (
                           'Error happened while archiving shipment headers data: '
                        || SQLERRM);
            END;

            /*Pick Ticket line interface*/
            BEGIN
                INSERT INTO xxdo.xxont_pick_intf_line_stg_log (
                                warehouse_code,
                                order_number,
                                line_number,
                                attribute12,
                                attribute11,
                                attribute10,
                                attribute9,
                                attribute8,
                                attribute7,
                                attribute6,
                                attribute5,
                                attribute4,
                                attribute3,
                                attribute2,
                                attribute1,
                                source_type,
                                last_update_login,
                                last_updated_by,
                                last_update_date,
                                created_by,
                                creation_date,
                                request_id,
                                error_message,
                                process_status,
                                unit_vat_number,
                                latest_ship_date,
                                scheduled_ship_date,
                                earliest_ship_date,
                                factory_purchase_order,
                                freight_amount_per_unit,
                                tax_amount_per_unit,
                                unit_selling_price,
                                unit_list_price,
                                unit_msrp_price,
                                customer_upc_number,
                                customer_size_name,
                                customer_color_name,
                                customer_style_name,
                                customer_item_number,
                                cust_po_number,
                                sales_order_number,
                                comments,
                                reason_description,
                                reason_code,
                                order_uom,
                                qty,
                                item_number,
                                carton_crossdock_ref,
                                harmonized_tariff_code,
                                line_id,
                                header_id,
                                record_type,
                                destination,
                                SOURCE,
                                atttribute20,
                                atribute19,
                                attribute18,
                                attribute17,
                                attribute16,
                                attribute15,
                                attribute14,
                                attribute13,
                                archive_date,
                                archive_request_id,
                                batch_number,
                                customer_item_price,   -- Added for Change 3.0
                                customer_style_number  -- Added for Change 3.0
                                                     )
                    SELECT warehouse_code, order_number, line_number,
                           attribute12, attribute11, attribute10,
                           attribute9, attribute8, attribute7,
                           attribute6, attribute5, attribute4,
                           attribute3, attribute2, attribute1,
                           source_type, last_update_login, last_updated_by,
                           last_update_date, created_by, creation_date,
                           request_id, error_message, process_status,
                           unit_vat_number, latest_ship_date, scheduled_ship_date,
                           earliest_ship_date, factory_purchase_order, freight_amount_per_unit,
                           tax_amount_per_unit, unit_selling_price, unit_list_price,
                           unit_msrp_price, customer_upc_number, customer_size_name,
                           customer_color_name, customer_style_name, customer_item_number,
                           cust_po_number, sales_order_number, comments,
                           reason_description, reason_code, order_uom,
                           qty, item_number, carton_crossdock_ref,
                           harmonized_tariff_code, line_id, header_id,
                           record_type, destination, SOURCE,
                           atttribute20, atribute19, attribute18,
                           attribute17, attribute16, attribute15,
                           attribute14, attribute13, l_dte_sysdate,
                           g_num_request_id, batch_number, customer_item_price, -- Added for Change 3.0
                           customer_style_number       -- Added for Change 3.0
                      FROM xxdo.xxont_pick_intf_line_stg
                     WHERE     process_status = gc_processed_status
                           AND order_number = rec_delivery.order_number;

                DELETE FROM
                    xxdo.xxont_pick_intf_line_stg
                      WHERE     process_status = gc_processed_status
                            AND order_number = rec_delivery.order_number;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg (
                           'Error happened while archiving Pick Ticket Line Data '
                        || SQLERRM);
            END;

            /*Pick Ticket comment header interface*/
            BEGIN
                INSERT INTO xxdo.xxont_pick_intf_cmt_hdr_s_log (
                                warehouse_code,
                                order_number,
                                comment_id,
                                header_id,
                                record_type,
                                destination,
                                SOURCE,
                                attribute20,
                                attribute19,
                                attribute18,
                                attribute17,
                                attribute16,
                                attribute15,
                                attribute14,
                                attribute13,
                                attribute12,
                                attribute11,
                                attribute10,
                                attribute9,
                                attribute8,
                                attribute7,
                                attribute6,
                                attribute5,
                                attribute4,
                                attribute3,
                                attribute2,
                                attribute1,
                                source_type,
                                last_update_login,
                                last_updated_by,
                                last_update_date,
                                created_by,
                                creation_date,
                                request_id,
                                error_message,
                                process_status,
                                comment_text,
                                comment_sequence,
                                comment_type,
                                archive_date,
                                archive_request_id,
                                batch_number)
                    SELECT warehouse_code, order_number, comment_id,
                           header_id, record_type, destination,
                           SOURCE, attribute20, attribute19,
                           attribute18, attribute17, attribute16,
                           attribute15, attribute14, attribute13,
                           attribute12, attribute11, attribute10,
                           attribute9, attribute8, attribute7,
                           attribute6, attribute5, attribute4,
                           attribute3, attribute2, attribute1,
                           source_type, last_update_login, last_updated_by,
                           last_update_date, created_by, creation_date,
                           request_id, error_message, process_status,
                           comment_text, comment_sequence, comment_type,
                           l_dte_sysdate, g_num_request_id, batch_number
                      FROM xxdo.xxont_pick_intf_cmt_hdr_stg
                     WHERE     process_status = gc_processed_status
                           AND order_number = rec_delivery.order_number;

                DELETE FROM
                    xxdo.xxont_pick_intf_cmt_hdr_stg
                      WHERE     process_status = gc_processed_status
                            AND order_number = rec_delivery.order_number;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg (
                           'Error happened while archiving Pick Ticket Comment Header Data '
                        || SQLERRM);
            END;

            /*Pick Ticket comment line interface*/
            BEGIN
                INSERT INTO xxdo.xxont_pick_intf_cmt_line_s_log (
                                warehouse_code,
                                order_number,
                                line_number,
                                comment_id,
                                line_id,
                                record_type,
                                destination,
                                SOURCE,
                                attribute20,
                                attribute19,
                                attribute18,
                                attribute17,
                                attribute16,
                                attribute15,
                                attribute14,
                                attribute13,
                                attribute12,
                                attribute11,
                                attribute10,
                                attribute9,
                                attribute8,
                                attribute7,
                                attribute6,
                                attribute5,
                                attribute4,
                                attribute3,
                                attribute2,
                                attribute1,
                                source_type,
                                last_update_login,
                                last_updated_by,
                                last_update_date,
                                created_by,
                                creation_date,
                                request_id,
                                error_message,
                                process_status,
                                comment_text,
                                comment_sequence,
                                comment_type,
                                archive_date,
                                archive_request_id,
                                batch_number)
                    SELECT warehouse_code, order_number, line_number,
                           comment_id, line_id, record_type,
                           destination, SOURCE, attribute20,
                           attribute19, attribute18, attribute17,
                           attribute16, attribute15, attribute14,
                           attribute13, attribute12, attribute11,
                           attribute10, attribute9, attribute8,
                           attribute7, attribute6, attribute5,
                           attribute4, attribute3, attribute2,
                           attribute1, source_type, last_update_login,
                           last_updated_by, last_update_date, created_by,
                           creation_date, request_id, error_message,
                           process_status, comment_text, comment_sequence,
                           comment_type, l_dte_sysdate, g_num_request_id,
                           batch_number
                      FROM xxdo.xxont_pick_intf_cmt_line_stg
                     WHERE     process_status = gc_processed_status
                           AND order_number = rec_delivery.order_number;

                DELETE FROM
                    xxdo.xxont_pick_intf_cmt_line_stg
                      WHERE     process_status = gc_processed_status
                            AND order_number = rec_delivery.order_number;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg (
                           'Error happened while archiving Pick Ticket Comment Line Data '
                        || SQLERRM);
            END;

            /*Pick Ticket vas header interface*/
            BEGIN
                INSERT INTO xxdo.xxont_pick_intf_vas_hdr_s_log (
                                warehouse_code,
                                order_number,
                                vas_code,
                                vas_label_offset,
                                vas_label_justification,
                                vas_label_format,
                                record_id,
                                record_type,
                                destination,
                                SOURCE,
                                attribute20,
                                attribute19,
                                attribute18,
                                attribute17,
                                attribute16,
                                attribute15,
                                attribute14,
                                attribute13,
                                attribute12,
                                attribute11,
                                attribute10,
                                attribute9,
                                attribute8,
                                attribute7,
                                attribute6,
                                attribute5,
                                attribute4,
                                attribute3,
                                atttribute2,
                                attribute1,
                                source_type,
                                last_update_login,
                                last_updated_by,
                                last_update_date,
                                created_by,
                                creation_date,
                                request_id,
                                error_message,
                                process_status,
                                vas_label_type,
                                vas_item_number,
                                vas_description,
                                archive_date,
                                archive_request_id,
                                batch_number)
                    SELECT warehouse_code, order_number, vas_code,
                           vas_label_offset, vas_label_justification, vas_label_format,
                           record_id, record_type, destination,
                           SOURCE, attribute20, attribute19,
                           attribute18, attribute17, attribute16,
                           attribute15, attribute14, attribute13,
                           attribute12, attribute11, attribute10,
                           attribute9, attribute8, attribute7,
                           attribute6, attribute5, attribute4,
                           attribute3, atttribute2, attribute1,
                           source_type, last_update_login, last_updated_by,
                           last_update_date, created_by, creation_date,
                           request_id, error_message, process_status,
                           vas_label_type, vas_item_number, vas_description,
                           l_dte_sysdate, g_num_request_id, batch_number
                      FROM xxdo.xxont_pick_intf_vas_hdr_stg
                     WHERE     process_status = gc_processed_status
                           AND order_number = rec_delivery.order_number;

                DELETE FROM
                    xxdo.xxont_pick_intf_vas_hdr_stg
                      WHERE     process_status = gc_processed_status
                            AND order_number = rec_delivery.order_number;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg (
                           'Error happened while archiving Pick Ticket Vas Header Data '
                        || SQLERRM);
            END;

            /*Pick Ticket vas line interface*/
            BEGIN
                INSERT INTO xxdo.xxont_pick_intf_vas_line_s_log (
                                warehouse_code,
                                order_number,
                                line_number,
                                atttribute12,
                                atttribute11,
                                atttribute10,
                                atttribute9,
                                atttribute8,
                                atttribute7,
                                atttribute6,
                                atttribute5,
                                atttribute4,
                                atttribute3,
                                atttribute2,
                                attribute1,
                                source_type,
                                last_updated_by,
                                last_update_date,
                                created_by,
                                creation_date,
                                request_id,
                                error_message,
                                process_status,
                                vas_label_type,
                                vas_item_number,
                                vas_description,
                                vas_code,
                                record_id,
                                record_type,
                                destination,
                                SOURCE,
                                atttribute20,
                                atttribute19,
                                atttribute18,
                                atttribute17,
                                atttribute16,
                                atttribute15,
                                atttribute14,
                                atttribute13,
                                archive_date,
                                archive_request_id,
                                batch_number)
                    SELECT warehouse_code, order_number, line_number,
                           atttribute12, atttribute11, atttribute10,
                           atttribute9, atttribute8, atttribute7,
                           atttribute6, atttribute5, atttribute4,
                           atttribute3, atttribute2, attribute1,
                           source_type, last_updated_by, last_update_date,
                           created_by, creation_date, request_id,
                           error_message, process_status, vas_label_type,
                           vas_item_number, vas_description, vas_code,
                           record_id, record_type, destination,
                           SOURCE, atttribute20, atttribute19,
                           atttribute18, atttribute17, atttribute16,
                           atttribute15, atttribute14, atttribute13,
                           l_dte_sysdate, g_num_request_id, batch_number
                      FROM xxdo.xxont_pick_intf_vas_line_stg
                     WHERE     process_status = gc_processed_status
                           AND order_number = rec_delivery.order_number;

                DELETE FROM
                    xxdo.xxont_pick_intf_vas_line_stg
                      WHERE     process_status = gc_processed_status
                            AND order_number = rec_delivery.order_number;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg (
                           'Error happened while archiving Pick Ticket VAS Line Data '
                        || SQLERRM);
            END;

            /*Pick Ticket  serial interface*/
            BEGIN
                INSERT INTO xxdo.xxont_pick_intf_serial_stg_log (
                                warehouse_code,
                                order_number,
                                line_number,
                                item_number,
                                serial_number,
                                line_id,
                                header_id,
                                record_type,
                                destination,
                                SOURCE,
                                atttribute20,
                                atribute19,
                                attribute18,
                                attribute17,
                                attribute16,
                                attribute15,
                                attribute14,
                                attribute13,
                                attribute12,
                                attribute11,
                                attribute10,
                                attribute9,
                                attribute8,
                                attribute7,
                                attribute6,
                                attribute5,
                                attribute4,
                                attribute3,
                                attribute2,
                                attribute1,
                                source_type,
                                last_update_login,
                                last_updated_by,
                                last_update_date,
                                created_by,
                                creation_date,
                                request_id,
                                error_message,
                                process_status,
                                archive_date,
                                archive_request_id,
                                batch_number)
                    SELECT warehouse_code, order_number, line_number,
                           item_number, serial_number, line_id,
                           header_id, record_type, destination,
                           SOURCE, atttribute20, atribute19,
                           attribute18, attribute17, attribute16,
                           attribute15, attribute14, attribute13,
                           attribute12, attribute11, attribute10,
                           attribute9, attribute8, attribute7,
                           attribute6, attribute5, attribute4,
                           attribute3, attribute2, attribute1,
                           source_type, last_update_login, last_updated_by,
                           last_update_date, created_by, creation_date,
                           request_id, error_message, process_status,
                           l_dte_sysdate, g_num_request_id, batch_number
                      FROM xxdo.xxont_pick_intf_serial_stg
                     WHERE     process_status = gc_processed_status
                           AND order_number = rec_delivery.order_number;

                DELETE FROM
                    xxdo.xxont_pick_intf_serial_stg
                      WHERE     process_status = gc_processed_status
                            AND order_number = rec_delivery.order_number;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg (
                           'Error happened while archiving Pick Ticket Serial Data '
                        || SQLERRM);
            END;

            BEGIN
                --Delete the closed deliveries from the pick status table
                DELETE FROM
                    xxdo.xxdo_ont_pick_status_order xps
                      WHERE     1 = 1
                            AND xps.order_number = rec_delivery.order_number;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg (
                           'Error happened while deleting the closed Pick Tickets in Pick Status Order Status staging table '
                        || SQLERRM);
            END;
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
            'EBS to HJ integration tables purge program completed');
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexepected error while purging the records' || SQLERRM);
    END archive_stg_data;

    /****************************************************************************
    -- Procedure Name   :   purge_archive
    -- Description      :   This procedure is to archive and purge the old data
    -- Parameters       :   p_out_chr_errbuf    OUT : Error message
    --                      p_out_chr_retcode   OUT : Execution
    -- Return/Exit      :   None
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date         Author              Version Description
    -- ----------   ------------------  ------- ---------------------------------
    -- 2015/01/28   Infosys             1.0     Initial Version.
    -- 01/23/2018   Deckers             1.1     CCR0006944- Added prepick date and cancel date columns
    -- 04/04/2018   Kranthi Bollam      2.0     CCR0007089 - Created a separate concurrent program for
    --                                          this purge procedure
    -- 02/24/2019   Kranthi Bollam      2.1     CCR0007774 - Updated purging logic
    ***************************************************************************/
    PROCEDURE purge_archive (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_purge_days IN NUMBER
                             , p_in_num_purge_log_days IN NUMBER)
    IS
        l_dte_sysdate   DATE := SYSDATE;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'EBS to HJ integration tables purge program started.');
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';
        fnd_file.put_line (fnd_file.LOG, 'Parameters.');
        fnd_file.put_line (fnd_file.LOG, '----------------------');
        fnd_file.put_line (
            fnd_file.LOG,
            'Purge Staging table Obselete Data Days:' || p_in_num_purge_days);
        fnd_file.put_line (
            fnd_file.LOG,
            'Purge log table processed Data Days:' || p_in_num_purge_log_days);
        fnd_file.put_line (fnd_file.LOG, '----------------------');
        fnd_file.put_line (
            fnd_file.LOG,
            'Purging ' || p_in_num_purge_days || ' days old records...');

        IF p_in_num_purge_days IS NOT NULL
        THEN
            msg (
                   'Calling purge_stg_data procedure - START. Timestamp: '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
            purge_stg_data (p_in_num_purge_days);
            msg (
                   'Calling purge_stg_data procedure - END. Timestamp: '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
            msg (
                   'Calling archive_stg_data procedure - START. Timestamp: '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
            archive_stg_data;
            msg (
                   'Calling archive_stg_data procedure - END. Timestamp: '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        END IF;

        IF p_in_num_purge_log_days IS NOT NULL
        THEN
            msg (
                   'Calling purge_log_data procedure - START. Timestamp: '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
            purge_log_data (p_in_num_purge_log_days);
            msg (
                   'Calling purge_log_data procedure - END. Timestamp: '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
            'EBS to HJ integration tables purge program completed');
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            p_out_chr_retcode   := '1';
            p_out_chr_errbuf    := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexepected error while purging the records' || SQLERRM);
    END purge_archive;

    /*
    ***********************************************************************************
    Procedure/Function Name  :  extract_pickticket_stage_data
    Description              :  This procedure extracts pick ticket details into staging tables
    **********************************************************************************
    /*-- 01/23/2018 Deckers           1.1   CCR0006944- Added prepick date and cancel date columns and modified earliest ship date logic */
    PROCEDURE extract_pickticket_stage_data (
        p_organization     IN     NUMBER,
        p_pick_num         IN     NUMBER,
        p_so_num           IN     NUMBER,
        p_brand            IN     VARCHAR2              --Added for change 2.0
                                          ,
        p_sales_channel    IN     VARCHAR2              --Added for change 2.0
                                          ,
        p_regenerate_xml   IN     VARCHAR2              --Added for change 2.0
                                          ,
        p_last_run_date    IN     DATE,
        p_source           IN     VARCHAR2,
        p_dest             IN     VARCHAR2,
        p_retcode             OUT NUMBER,
        p_error_buf           OUT VARCHAR2)
    IS
        --Cursor to get inventory orgs
        CURSOR c_org IS
            SELECT organization_id
              FROM mtl_parameters mp
             WHERE     1 = 1
                   AND mp.organization_id =
                       NVL (p_organization, mp.organization_id)
                   AND mp.organization_code IN
                           (SELECT lookup_code
                              FROM fnd_lookup_values fvl
                             WHERE     1 = 1
                                   AND fvl.lookup_type = 'XXONT_WMS_WHSE'
                                   AND NVL (LANGUAGE, USERENV ('LANG')) =
                                       USERENV ('LANG')
                                   AND fvl.enabled_flag = 'Y');

        --Cursor to get deliveries eliglible to send to Highjump
        CURSOR c_pick_hdr (in_num_warehouse_id IN NUMBER)
        IS
            -----NEW DELIVERIES QUERY--------------------
            SELECT DISTINCT /*+ FULL(pick, pick_log) */
                            wnd.delivery_id delivery_id
              FROM apps.wsh_new_deliveries wnd, apps.wsh_delivery_assignments wda, apps.wsh_delivery_details wdd,
                   apps.oe_order_lines_all ool, apps.oe_order_headers_all ooh
             WHERE     1 = 1
                   AND wnd.organization_id = in_num_warehouse_id
                   --Added for change 2.0
                   AND wnd.status_code = 'OP'
                   --Delivery should be in Open Status
                   AND wnd.delivery_id = NVL (p_pick_num, wnd.delivery_id)
                   AND wnd.attribute11 IS NULL
                   AND wnd.delivery_id = wda.delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wdd.source_code = 'OE'           --Added for change 2.0
                   AND wdd.organization_id = wnd.organization_id
                   --Added for change 2.0
                   AND wdd.released_status = 'S'        --Added for change 2.0
                   AND wdd.source_line_id = ool.line_id
                   AND wdd.source_header_id = ool.header_id
                   --Added for change 2.0
                   --AND wdd.source_header_id = ooh.header_id --Commented for change 2.0
                   AND wdd.organization_id = ool.ship_from_org_id
                   --Added for change 2.0
                   AND ool.flow_status_code = 'AWAITING_SHIPPING'
                   AND ool.header_id = ooh.header_id
                   AND ooh.order_number = NVL (p_so_num, ooh.order_number)
                   ---Order should not have any Holds------------
                   AND NOT EXISTS
                           (SELECT '1'
                              FROM oe_order_holds_all oohs
                             ---Modified for OU BUG 06-Apr-2015
                             WHERE     1 = 1
                                   AND oohs.released_flag = 'N'
                                   AND oohs.line_id IS NULL
                                   AND oohs.header_id = ooh.header_id)
                   --AND ool.ship_from_org_id = in_num_warehouse_id --Commented for change 2.0
                   -----Delivery Should not be in PROCESSED or INPROCESS or NEW status in pick interface header stg table------
                   AND NOT EXISTS
                           (SELECT '1'
                              FROM apps.xxont_pick_intf_hdr_stg pick
                             WHERE     1 = 1
                                   AND pick.order_number = wnd.delivery_id
                                   AND pick.process_status IN
                                           (gc_processed_status, gc_inprocess_status, gc_new_status) --Added for change 2.1
                                                                                                    )
                   -----Delivery Should not be in Processed status in pick interface header LOG table------
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.xxont_pick_intf_hdr_stg_log pick_log
                             WHERE     1 = 1
                                   AND pick_log.order_number =
                                       wnd.delivery_id
                                   AND pick_log.process_status =
                                       gc_processed_status)
                   AND ooh.attribute5 = NVL (p_brand, ooh.attribute5)
                   --Added Brand parameter for change 2.0
                   --Added get_sales_channel function for change 2.1 --START
                   AND NVL (get_sales_channel (ooh.header_id), 'X') =
                       NVL (
                           NVL (p_sales_channel,
                                get_sales_channel (ooh.header_id)),
                           'X')
                   --Added get_sales_channel function for change 2.1 --END
                   --Added to restrict "Planned for cross docking" status orders to HJ for change 2.5 --START
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.wsh_delivery_details wd, apps.wsh_delivery_assignments wdaa
                             WHERE     wd.move_order_line_id IS NULL
                                   AND wd.released_status = 'S'
                                   AND wd.source_code = 'OE'
                                   AND wd.delivery_detail_id =
                                       wdaa.delivery_detail_id
                                   AND wd.organization_id =
                                       wnd.organization_id
                                   AND wdaa.delivery_id = wnd.delivery_id)
            --Added to restrict "Planned for cross docking" status orders to HJ for change 2.5 --END
            UNION
            -----------QUERY TO GET UPDATED DELIVERIES-----------------
            --START - Added below select for change 2.3(Logic to derive updated deliveries is modified using below query)
            SELECT DISTINCT upd_delv.delivery_id
              FROM (SELECT open_del.*, stg_del.*
                      FROM (                    --Query to get open deliveries
                              SELECT /*+ FULL(xps) */
                                     wnd.delivery_id delivery_id, ooh.header_id, ooh.cust_po_number,
                                     NVL (TRUNC (MAX (fnd_date.canonical_to_date (ool.attribute1))), TRUNC (fnd_date.canonical_to_date (ooh.attribute1))) cancel_date
                                FROM apps.wsh_new_deliveries wnd, apps.wsh_delivery_assignments wda, apps.wsh_delivery_details wdd,
                                     apps.oe_order_lines_all ool, apps.oe_order_headers_all ooh
                               WHERE     1 = 1
                                     AND wnd.organization_id =
                                         in_num_warehouse_id
                                     AND wnd.status_code = 'OP'
                                     AND wnd.delivery_id =
                                         NVL (p_pick_num, wnd.delivery_id)
                                     AND wnd.attribute11 IS NULL
                                     AND wnd.delivery_id = wda.delivery_id
                                     AND wda.delivery_detail_id =
                                         wdd.delivery_detail_id
                                     AND wdd.source_code = 'OE'
                                     AND wdd.organization_id =
                                         wnd.organization_id
                                     AND wdd.released_status IN ('S', 'Y')
                                     -- For staged lines we need to consider updates
                                     AND wdd.source_line_id = ool.line_id
                                     AND wdd.source_header_id = ool.header_id
                                     AND wdd.organization_id =
                                         ool.ship_from_org_id
                                     AND ool.flow_status_code =
                                         'AWAITING_SHIPPING'
                                     AND ool.header_id = ooh.header_id
                                     AND ooh.order_number =
                                         NVL (p_so_num, ooh.order_number)
                                     ---Order should not have any Holds------------
                                     AND NOT EXISTS
                                             (SELECT '1'
                                                FROM oe_order_holds_all oohs
                                               WHERE     1 = 1
                                                     AND oohs.released_flag =
                                                         'N'
                                                     AND oohs.line_id IS NULL
                                                     AND oohs.header_id =
                                                         ooh.header_id)
                                     AND ooh.attribute5 =
                                         NVL (p_brand, ooh.attribute5)
                                     --Added below get_sales_channel function for change 2.1 - START
                                     AND NVL (
                                             apps.xxd_wms_hj_int_pkg.get_sales_channel (
                                                 ooh.header_id),
                                             'X') =
                                         NVL (
                                             p_sales_channel,
                                             NVL (
                                                 apps.xxd_wms_hj_int_pkg.get_sales_channel (
                                                     ooh.header_id),
                                                 'X'))
                                     --Exclude deliveries with status as SHIPPED
                                     AND NOT EXISTS
                                             (SELECT '1'
                                                FROM xxdo.xxdo_ont_pick_status_order xps
                                               WHERE     1 = 1
                                                     AND order_number =
                                                         wnd.delivery_id
                                                     AND status = 'SHIPPED')
                                     --Added to restrict "Planned for cross docking" status orders to HJ for change 2.5 --START
                                     AND NOT EXISTS
                                             (SELECT 1
                                                FROM apps.wsh_delivery_details wd, apps.wsh_delivery_assignments wdaa
                                               WHERE     wd.move_order_line_id
                                                             IS NULL
                                                     AND wd.released_status =
                                                         'S'
                                                     AND wd.source_code = 'OE'
                                                     AND wd.delivery_detail_id =
                                                         wdaa.delivery_detail_id
                                                     AND wd.organization_id =
                                                         wnd.organization_id
                                                     AND wdaa.delivery_id =
                                                         wnd.delivery_id)
                            --Added to restrict "Planned for cross docking" status orders to HJ for change 2.5 --END
                            GROUP BY wnd.delivery_id, ooh.header_id, ooh.cust_po_number,
                                     TRUNC (fnd_date.canonical_to_date (ooh.attribute1)))
                           open_del,
                           ( --Query to get the deliveries from the staging tables
                            SELECT /*+ FULL(ph) */
                                   ph.warehouse_code, ph.order_number, ph.order_type,
                                   ph.brand_code, ph.status, ph.process_status,
                                   ph.source_type, ph.cust_po_number, ph.latest_ship_date
                              FROM xxdo.xxont_pick_intf_hdr_stg ph
                             WHERE     1 = 1
                                   AND ph.source_type = 'ORDER'
                                   AND ph.process_status = 'PROCESSED'
                                   AND ph.brand_code =
                                       NVL (p_brand, ph.brand_code)
                            UNION
                            SELECT /*+ FULL(ph_log) */
                                   ph_log.warehouse_code, ph_log.order_number, ph_log.order_type,
                                   ph_log.brand_code, ph_log.status, ph_log.process_status,
                                   ph_log.source_type, ph_log.cust_po_number, ph_log.latest_ship_date
                              FROM xxdo.xxont_pick_intf_hdr_stg_log ph_log
                             WHERE     1 = 1
                                   AND ph_log.source_type = 'ORDER'
                                   AND ph_log.process_status = 'PROCESSED'
                                   AND ph_log.brand_code =
                                       NVL (p_brand, ph_log.brand_code))
                           stg_del
                     WHERE     1 = 1
                           AND open_del.delivery_id = stg_del.order_number
                           AND (stg_del.cust_po_number <> SUBSTR (open_del.cust_po_number, 1, 30) OR TRUNC (stg_del.latest_ship_date) <> open_del.cancel_date))
                   upd_delv
             WHERE 1 = 1
            UNION            /* Added for 2.3  Delivery or Order re-extract */
            SELECT DISTINCT /*+ FULL(xps) */
                            wnd.delivery_id delivery_id
              FROM apps.wsh_new_deliveries wnd, apps.wsh_delivery_assignments wda, apps.wsh_delivery_details wdd,
                   apps.oe_order_lines_all ool, apps.oe_order_headers_all ooh
             WHERE     1 = 1
                   AND wnd.organization_id = in_num_warehouse_id
                   AND wnd.status_code = 'OP'
                   AND wnd.delivery_id = NVL (p_pick_num, wnd.delivery_id)
                   AND wnd.attribute11 IS NULL
                   AND wnd.delivery_id = wda.delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wdd.source_code = 'OE'
                   AND wdd.organization_id = wnd.organization_id
                   --AND wdd.released_status IN ('S', 'Y')   -- Commented as per ver 2.6
                   AND wdd.released_status = 'S'     -- Changes as per ver 2.6
                   AND wdd.source_line_id = ool.line_id
                   AND wdd.source_header_id = ool.header_id
                   AND wdd.organization_id = ool.ship_from_org_id
                   AND ool.flow_status_code = 'AWAITING_SHIPPING'
                   AND ool.header_id = ooh.header_id
                   AND ooh.order_number = NVL (p_so_num, ooh.order_number)
                   ---Order should not have any Holds------------
                   AND NOT EXISTS
                           (SELECT '1'
                              FROM oe_order_holds_all oohs
                             WHERE     1 = 1
                                   AND oohs.released_flag = 'N'
                                   AND oohs.line_id IS NULL
                                   AND oohs.header_id = ooh.header_id)
                   AND (p_pick_num IS NOT NULL OR p_so_num IS NOT NULL) --Only for the Reextaction logic
                   AND NOT EXISTS
                           (SELECT '1'
                              FROM xxdo.xxdo_ont_pick_status_order xps
                             WHERE     1 = 1
                                   AND order_number = wnd.delivery_id
                                   AND status = 'SHIPPED')
                   --Added to restrict "Planned for cross docking" status orders to HJ for change 2.5 --START
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.wsh_delivery_details wd, apps.wsh_delivery_assignments wdaa
                             WHERE     wd.move_order_line_id IS NULL
                                   AND wd.released_status = 'S'
                                   AND wd.source_code = 'OE'
                                   AND wd.delivery_detail_id =
                                       wdaa.delivery_detail_id
                                   AND wd.organization_id =
                                       wnd.organization_id
                                   AND wdaa.delivery_id = wnd.delivery_id) --Added to restrict "Planned for cross docking" status orders to HJ for change 2.5 --END
                                                                          ;

        --Cursor to get Delivery Information
        CURSOR c_pick_data (in_num_warehouse_id   IN NUMBER,
                            in_num_header_id      IN NUMBER)
        IS
              SELECT DISTINCT
                     --Added distinct for change 2.3 to avoid split delivery scenario on 17Apr2019.
                     hou.NAME
                         company,
                     mp.organization_code
                         warehouse_code,
                     wnd.NAME
                         order_number,
                     wnd.delivery_id
                         header_id,
                     oeoh.org_id,
                     oeol.line_id,
                     oeoh.attribute5
                         brand_code,
                     hca.account_number
                         customer_code,
                     oeoh.packing_instructions,
                     oeoh.shipping_instructions,
                     oeoh.attribute6
                         comments1,
                     oeoh.attribute7
                         comments2,
                     oeol.attribute3
                         musical_details,                         --CCR0008657
                     hpa.party_name
                         customer_name,
                     oeoh.ordered_date
                         order_date,
                     ottl.NAME
                         order_type,
                     --msi.concatenated_segments item_number, --Commented for change 2.0 -- Getting rid of mtl_system_items_kfv
                     xciv.item_number
                         item_number,                   --Added for change 2.0
                     --oeol.ordered_quantity qty,   --Commented as per change of ver 2.6
                     --START Added as per ver 2.6
                     (SELECT SUM (wdd1.requested_quantity)
                        FROM apps.wsh_new_deliveries wnd1, apps.wsh_delivery_assignments wda1, apps.wsh_delivery_details wdd1
                       WHERE     wnd1.delivery_id = wda1.delivery_id
                             AND wda1.delivery_detail_id =
                                 wdd1.delivery_detail_id
                             AND wdd1.organization_id =
                                 wnd1.organization_id
                             AND wdd1.source_code = 'OE'
                             AND wdd1.source_header_id =
                                 wdd.source_header_id
                             AND wdd1.source_line_id =
                                 wdd.source_line_id
                             AND wnd1.delivery_id = wnd.delivery_id
                             AND wdd1.organization_id =
                                 wdd.organization_id)
                         qty,
                     --END Added as per ver 2.6
                     oeol.order_quantity_uom
                         order_uom,
                     NULL
                         reason_code,
                     NULL
                         reason_description,
                     oeol.packing_instructions
                         line_packing_instructions,
                     oeol.shipping_instructions
                         line_shipping_instructions,
                     oeoh.order_number
                         ref_sales_order_number,
                     SUBSTR (oeoh.cust_po_number, 1, 30)
                         ref_cust_po_number,
                     TO_CHAR (
                         TO_DATE (oeoh.attribute1, 'YYYY/MM/DD HH24:MI:SS'))
                         latest_ship_date,                    --BT remediation
                     --Begin CCR0008657
                     --   oeoh.attribute14
                     NULL
                         vas_code,
                     oeoh.request_date
                         earliest_ship_date,
                     --NULL earliest_ship_date,
                     oeol.schedule_ship_date
                         schedule_ship_date,
                     --NULL schedule_ship_date,
                     --End CCR0008657
                     wc.carrier_name,
                     wc.carrier_id,
                     wc.freight_code
                         carrier,
                     --oeol.shipping_method_code service_level_code, --Commented on 31MAY2018 for HPQC Defect # 1035 (Change 2.0)
                     NVL (oeol.shipping_method_code, oeoh.shipping_method_code)
                         service_level_code,
                     --Added on 31MAY2018 for HPQC Defect # 1035 (Change 2.0)
                     wcs.service_level
                         service_level,
                     wdd.freight_terms_code,
                     hcsu_ship.LOCATION
                         ship_location,
                     hps_ship.party_site_name
                         ship_site,
                     hl_ship.address1
                         ship_address1,
                     hl_ship.address2
                         ship_address2,
                     hl_ship.address3
                         ship_address3,
                     hl_ship.city
                         ship_city,
                     NVL (hl_ship.state, hl_ship.province)
                         ship_state,
                     hl_ship.postal_code
                         ship_postal_code,
                     hl_ship.country
                         ship_country,
                     hcsu_bill.LOCATION
                         bill_location,
                     hps_bill.party_site_name
                         bill_site,
                     hl_bill.address1
                         bill_address1,
                     hl_bill.address2
                         bill_address2,
                     hl_bill.address3
                         bill_address3,
                     hl_bill.city
                         bill_city,
                     NVL (hl_bill.state, hl_bill.province)
                         bill_state,
                     hl_bill.postal_code
                         bill_postal_code,
                     hl_bill.country
                         bill_country,
                     hcas_ship.attribute2
                         store_number,
                     hcas_ship.attribute5
                         dc_number,
                     hcas_ship.attribute1
                         store_name,
                     xxd_wms_hj_int_pkg.parse_attributes (oeoh.attribute3,
                                                          'depart_number')
                         depart_number,
                     xxd_wms_hj_int_pkg.parse_attributes (oeoh.attribute4,
                                                          'depart_name')
                         depart_name,
                     xxd_wms_hj_int_pkg.parse_attributes (oeoh.attribute3,
                                                          'vendor')
                         vendor_number,
                     DECODE (hpa.party_type, 'PERSON', 'Y', 'N')
                         residential_flag,
                     --hca.attribute8 freight_account, --Commented for change 2.3 for freight changes
                     NVL (hcas_ship.attribute8, hca.attribute8)
                         freight_account,
                     --Added for change 2.3 for freight changes
                     oeoh.shipment_priority_code,
                     hcas_ship.cust_acct_site_id
                         ship_cust_acct_site_id,
                     hcas_bill.cust_acct_site_id
                         bill_cust_acct_site_id,
                     hpa.language_name
                         customer_language,
                     NULL
                         return_code,
                     NULL
                         return_address1,
                     NULL
                         return_address2,
                     NULL
                         return_address3,
                     NULL
                         return_city,
                     NULL
                         return_state,
                     NULL
                         return_postal_code,
                     NULL
                         return_country,
                     NULL
                         return_cust_acct_site_id,
                     hca.cust_account_id,
                     --msi.inventory_item_id, --Commented for change 2.0 -- Getting rid of mtl_system_items_kfv
                     xciv.inventory_item_id,            --Added for change 2.0
                     oeol.unit_list_price,
                     ROUND (oeol.unit_selling_price, 2)
                         unit_selling_price,
                     ROUND (oeol.tax_value / oeol.ordered_quantity, 2)
                         unit_tax_amount,
                     xciv.style_number
                         item_style,
                     mp.organization_id,
                     oeoh.attribute9
                         special_vas,
                     DECODE (oeoh.attribute9, 'Y', oeol.attribute15, '')
                         crossdock_ref,
                     oeoh.order_source_id,
                     oeoh.attribute16
                         order_pack_type,
                     oeol.attribute14
                         vas_line_code,
                     oeol.attribute8
                         cust_sku_code,
                     xxd_wms_hj_int_pkg.parse_attributes (oeol.attribute8,
                                                          'item_id')
                         customer_item_number,
                     xxd_wms_hj_int_pkg.parse_attributes (oeol.attribute8,
                                                          'style_desc')
                         customer_style_name,
                     xxd_wms_hj_int_pkg.parse_attributes (oeol.attribute8,
                                                          'color_desc')
                         customer_color_name,
                     xxd_wms_hj_int_pkg.parse_attributes (oeol.attribute8,
                                                          'size_desc')
                         customer_size_name,
                     xxd_wms_hj_int_pkg.parse_attributes (oeol.attribute8,
                                                          'dim_desc')
                         customer_dim_name,
                     xxd_wms_hj_int_pkg.parse_attributes (oeol.attribute8,
                                                          'free_desc1')
                         customer_free_desc1,
                     xxd_wms_hj_int_pkg.parse_attributes (oeol.attribute8,
                                                          'free_desc2')
                         customer_free_desc2,
                     hca.attribute2
                         vas_label_format,
                     ott.attribute12
                         normal_or_amazon,
                     oeoh.header_id
                         order_header_id,
                     (SELECT attribute_type
                        FROM xxdo.xxdoec_order_attribute
                       WHERE     1 = 1 --AND attribute_type IN ('CLOSETORDER') --Commented for change 2.0
                             AND attribute_type = 'CLOSETORDER' --Added for change 2.0
                             AND order_header_id = oeoh.header_id
                             AND ROWNUM = 1)
                         attribute_type,
                     oeol.attribute7
                         customer_style_number,        -- Added for Change 3.0
                     --Begin CCR0008657
                     oeol.ship_to_org_id,
                     oeol.sold_to_org_id,
                     --End CCR0008657,
                     oeol.attribute10
                         customer_item_price            --added 4.2 CCR0009359
                FROM apps.wsh_new_deliveries wnd, apps.wsh_delivery_assignments wda, apps.wsh_delivery_details wdd,
                     apps.oe_order_lines_all oeol, apps.oe_order_headers_all oeoh, apps.oe_transaction_types_all ott,
                     apps.oe_transaction_types_tl ottl, apps.mtl_parameters mp, apps.hz_cust_accounts hca,
                     hr_operating_units hou, apps.hz_parties hpa --,mtl_system_items_kfv msi --Commented for change 2.0. This table is no longer required
                                                                , wsh_carriers_v wc,
                     wsh_carrier_services wcs, apps.hz_cust_site_uses_all hcsu_ship, apps.hz_cust_acct_sites_all hcas_ship,
                     apps.hz_party_sites hps_ship, apps.hz_locations hl_ship, apps.hz_cust_site_uses_all hcsu_bill,
                     apps.hz_cust_acct_sites_all hcas_bill, apps.hz_party_sites hps_bill, apps.hz_locations hl_bill,
                     apps.xxd_common_items_v xciv
               WHERE     1 = 1
                     AND wnd.organization_id = in_num_warehouse_id
                     --Added for change 2.0
                     AND wnd.delivery_id = in_num_header_id
                     AND wnd.status_code = 'OP'         --Added for change 2.0
                     AND wnd.delivery_id = wda.delivery_id
                     AND wda.delivery_detail_id = wdd.delivery_detail_id
                     AND wdd.source_code = 'OE'
                     AND wdd.organization_id = wnd.organization_id
                     --Added for change 2.0
                     AND wdd.source_line_id = oeol.line_id
                     AND wdd.source_header_id = oeol.header_id
                     --Added for change 2.0
                     AND oeol.line_category_code = 'ORDER'
                     AND wdd.organization_id = oeol.ship_from_org_id
                     --Added for change 2.0
                     AND oeol.header_id = oeoh.header_id
                     AND oeoh.booked_flag = 'Y'
                     AND hou.organization_id = oeoh.org_id
                     AND ott.transaction_type_id = oeoh.order_type_id
                     AND ott.order_category_code IN ('ORDER', 'MIXED')
                     AND ottl.transaction_type_id = ott.transaction_type_id
                     AND ottl.LANGUAGE = USERENV ('LANG')
                     AND wnd.organization_id = mp.organization_id
                     --Added for change 2.0
                     --AND mp.organization_id = oeol.ship_from_org_id --Commented for change 2.0
                     AND oeoh.sold_to_org_id = hca.cust_account_id
                     AND hca.party_id = hpa.party_id
                     --AND msi.organization_id = mp.organization_id --Commented for change 2.0
                     --AND msi.organization_id = oeol.ship_from_org_id --Commented for change 2.0 --mtl_system_items_kfv is not required
                     --AND msi.inventory_item_id = oeol.inventory_item_id --Commented for change 2.0 --mtl_system_items_kfv is not required
                     --AND xciv.inventory_item_id = msi.inventory_item_id  --Commented for change 2.0 --mtl_system_items_kfv is not required
                     --AND xciv.organization_id = msi.organization_id --Commented for change 2.0 --mtl_system_items_kfv is not required
                     AND oeol.ship_from_org_id = xciv.organization_id
                     --Added for change 2.0
                     AND oeol.inventory_item_id = xciv.inventory_item_id
                     --Added for change 2.0
                     --AND mp.organization_id = in_num_warehouse_id --Commented for change 2.0
                     AND oeol.freight_carrier_code = wc.freight_code(+)
                     AND NVL (
                             oeol.deliver_to_org_id,
                             NVL (oeoh.deliver_to_org_id, oeol.ship_to_org_id)) =
                         hcsu_ship.site_use_id
                     AND hcsu_ship.cust_acct_site_id =
                         hcas_ship.cust_acct_site_id
                     AND hcas_ship.party_site_id = hps_ship.party_site_id
                     AND hps_ship.location_id = hl_ship.location_id
                     AND oeol.invoice_to_org_id = hcsu_bill.site_use_id
                     AND hcsu_bill.cust_acct_site_id =
                         hcas_bill.cust_acct_site_id
                     AND hcas_bill.party_site_id = hps_bill.party_site_id
                     AND hps_bill.location_id = hl_bill.location_id
                     AND wcs.ship_method_code(+) = oeol.shipping_method_code
            ORDER BY mp.organization_code, wnd.delivery_id, oeol.line_id;

        --Added below regenerate XML cursor for change 2.0
        CURSOR c_regen_xml (in_num_warehouse_id IN NUMBER)
        IS
            SELECT DISTINCT wnd.delivery_id delivery_id
              FROM apps.wsh_new_deliveries wnd, apps.wsh_delivery_assignments wda, apps.wsh_delivery_details wdd,
                   apps.oe_order_lines_all ool, apps.oe_order_headers_all ooh
             WHERE     1 = 1
                   AND wnd.organization_id = in_num_warehouse_id
                   --Added for change 2.0
                   AND wnd.status_code = 'OP'       ---Delivery should be open
                   AND wnd.delivery_id = NVL (p_pick_num, wnd.delivery_id)
                   -----AND wnd.attribute11 IS NULL  --Commented for change 2.0  --For Regeneration of XML
                   AND wnd.delivery_id = wda.delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wdd.source_code = 'OE'
                   AND wdd.organization_id = wnd.organization_id
                   --Added for change 2.0
                   AND wdd.released_status = 'S'        --Added for change 2.0
                   AND wdd.source_line_id = ool.line_id
                   --AND wdd.source_header_id = ooh.header_id --Commented for change 2.0
                   AND wdd.source_header_id = ool.header_id
                   --Added for change 2.0
                   AND wdd.organization_id = ool.ship_from_org_id
                   --Added for change 2.0
                   AND ool.flow_status_code = 'AWAITING_SHIPPING'
                   AND ool.header_id = ooh.header_id
                   AND ooh.order_number = NVL (p_so_num, ooh.order_number)
                   ---Order should not have any Holds------------
                   AND NOT EXISTS
                           (SELECT '1'
                              FROM oe_order_holds_all oohs
                             WHERE     1 = 1
                                   AND oohs.released_flag = 'N'
                                   AND oohs.line_id IS NULL
                                   AND oohs.header_id = ooh.header_id)
                   AND ooh.attribute5 = NVL (p_brand, ooh.attribute5)
                   --Added Brand parameter for change 2.0
                   --Added below Sales Channel parameter for change 2.0
                   /* --Commented the below sales channel condition for change 2.1
                   AND apps.fn_get_value(
                                        NULL,
                                        ooh.header_id,
                                        NULL,
                                        NULL,
                                        'ORDER_SOURCE'
                                        ) = NVL(p_sales_channel,
                                                apps.fn_get_value(
                                                                  NULL,
                                                                  ooh.header_id,
                                                                  NULL,
                                                                  NULL,
                                                                  'ORDER_SOURCE'
                                                                 )
                                               )
                   */
                   --Added below get_sales_channel function for change 2.1 - START
                   AND NVL (get_sales_channel (ooh.header_id), 'X') =
                       NVL (p_sales_channel,
                            NVL (get_sales_channel (ooh.header_id), 'X'))
                   --Added below get_sales_channel function for change 2.1 - END
                   AND (p_pick_num IS NOT NULL OR p_so_num IS NOT NULL)
                   --AND ool.ship_from_org_id = in_num_warehouse_id --Commented for change 2.0
                   --Added below for change 2.0 (Exclude deliveries with status as WAVED, PACKING, PACKED and SHIPPED)
                   AND NOT EXISTS
                           (SELECT '1'
                              FROM xxdo.xxdo_ont_pick_status_order
                             WHERE     1 = 1
                                   AND order_number = wnd.delivery_id --AND status IN ('WAVED', 'PACKING', 'PACKED', 'SHIPPED') --Commented by Kranthi Bollam on 22May2018
                                   AND status = 'SHIPPED' --Added by Kranthi Bollam on 22May2018
                                                         )
                   --Added below condition for change 2.1 - START------
                   AND NOT EXISTS
                           (SELECT '1'
                              FROM apps.xxont_pick_intf_hdr_stg pick
                             WHERE     1 = 1
                                   AND pick.order_number = wnd.delivery_id
                                   AND process_status IN
                                           (gc_inprocess_status, gc_new_status)) --Added below condition for change 2.1 - END------
                                                                                ;

        --Begin CCR0008657
        CURSOR c_vas_hdr (v_account_number VARCHAR2, n_pt_ship_to_id VARCHAR2, n_org_id NUMBER)
        IS
            SELECT vc.vas_code, vc.vas_comments, vd.description
              FROM (SELECT vas_code, vas_comments, ROW_NUMBER () OVER (PARTITION BY vas_code ORDER BY rec_rank) AS rownumber
                      FROM (SELECT vas_code, vas_comments, 1 rec_rank
                              FROM xxd_ont_vas_assignment_dtls_t tbl
                             WHERE     tbl.account_number = v_account_number
                                   AND tbl.attribute_value = n_pt_ship_to_id
                                   AND tbl.org_id = n_org_id
                                   AND attribute_level = 'SITE'
                            UNION
                            SELECT vas_code, vas_comments, 2 rec_rank
                              FROM xxd_ont_vas_assignment_dtls_t tbl
                             WHERE     tbl.account_number = v_account_number
                                   AND attribute_level = 'CUSTOMER'
                                   --There cannot be a SITE level VAS code defined for the ship-to/customer
                                   AND NOT EXISTS
                                           (SELECT NULL
                                              FROM xxd_ont_vas_assignment_dtls_t tbl
                                             WHERE     tbl.account_number =
                                                       v_account_number
                                                   AND tbl.attribute_value =
                                                       n_pt_ship_to_id
                                                   AND tbl.org_id = n_org_id
                                                   AND attribute_level =
                                                       'SITE')
                                   AND tbl.org_id = n_org_id
                            ORDER BY vas_code, rec_rank)) vc,
                   xxdo.xxd_ont_vas_code_details_t vd
             WHERE vc.rownumber = 1 AND vc.vas_code = vd.vas_code;

        CURSOR c_vas_line (v_account_number VARCHAR2, n_inventory_item_id NUMBER, n_org_id NUMBER)
        IS
            SELECT vc.vas_code, vc.vas_comments, vd.description
              FROM (SELECT vas_code, vas_comments, ROW_NUMBER () OVER (PARTITION BY vas_code ORDER BY rec_rank) AS rownumber
                      FROM (SELECT vas_code, vas_comments, 2 rec_rank
                              FROM xxd_ont_vas_assignment_dtls_t tbl
                             WHERE     tbl.account_number = v_account_number
                                   AND tbl.org_id = n_org_id
                                   AND tbl.attribute_value =
                                       (SELECT DISTINCT style_number
                                          FROM xxd_common_items_v
                                         WHERE inventory_item_id =
                                               n_inventory_item_id)
                                   AND attribute_level = 'STYLE'
                            UNION
                            SELECT vas_code, vas_comments, 1 rec_rank
                              FROM xxd_ont_vas_assignment_dtls_t tbl
                             WHERE     tbl.account_number = v_account_number
                                   AND tbl.org_id = n_org_id
                                   AND tbl.attribute_value =
                                       (SELECT DISTINCT
                                               style_number || '-' || color_code
                                          FROM xxd_common_items_v
                                         WHERE inventory_item_id =
                                               n_inventory_item_id)
                                   AND attribute_level = 'STYLE_COLOR'
                            ORDER BY vas_code, rec_rank)) vc,
                   xxdo.xxd_ont_vas_code_details_t vd
             WHERE vc.vas_code = vd.vas_code;

        --End CCR0008657

        --Local Variables Declaration
        l_num_count                    NUMBER := 0;
        l_chr_warehouse                VARCHAR2 (10);
        l_num_order_num                NUMBER;
        l_chr_commit                   VARCHAR2 (1);
        l_num_comment_count            NUMBER;
        l_num_stg_header_id            NUMBER;
        l_num_stg_line_id              NUMBER;
        l_num_stg_hdr_cmt_id           NUMBER;
        l_num_stg_line_cmt_id          NUMBER;
        l_chr_bill_email               VARCHAR2 (50);
        l_chr_ship_email               VARCHAR2 (50);
        l_chr_bill_phone               VARCHAR2 (50);
        l_chr_ship_phone               VARCHAR2 (50);
        l_chr_return_phone             VARCHAR2 (50);
        l_chr_customer_item            VARCHAR2 (50);
        l_chr_hts_code                 VARCHAR2 (50);
        l_num_freight_amount           NUMBER;
        l_chr_order_type               VARCHAR2 (50);
        l_chr_order_source             VARCHAR2 (50);
        l_chr_duty_terms               VARCHAR2 (10);
        l_chr_duty_account_number      VARCHAR2 (50);
        l_chr_charge_service_level     VARCHAR2 (30);
        l_chr_saturday_delivery_flag   VARCHAR2 (1);
        l_chr_dc_number                VARCHAR2 (240);            --CCR0009572
        --Variable declaration for ecomm orders
        l_chr_ecomm_phone              VARCHAR2 (100);
        l_chr_ecomm_website            VARCHAR2 (100);
        l_chr_newgistic_data           VARCHAR2 (100);
        l_chr_usps_data                VARCHAR2 (100);
        --Variable declaration for Drop ship customers.
        l_chr_drop_cust_contact        fnd_lookup_values.description%TYPE;
        l_chr_drop_cust_name           VARCHAR2 (360);
        l_num_drop_ship_count          NUMBER;
        ---Variable declaration for VAS codes
        l_vas_code_tbl                 vas_code_type_tbl;
        l_line_vas_code_tbl            vas_code_type_tbl;
        lv_num_total                   NUMBER;
        ld_cancel_date                 DATE;
        ld_prepick_date                DATE;
        ld_request_date                DATE;
        --Variable declarations for Regenerate XML
        l_ret_sts                      NUMBER := 0;
        l_ret_message                  VARCHAR2 (2000) := NULL;
        l_in_regen_cursor              VARCHAR2 (1) := 'N';
        l_error_msg                    VARCHAR2 (2000) := NULL;
        -- Variables declared for VAS Code
        l_num_stg_hdr_vas_id           NUMBER;
        l_num_stg_line_vas_id          NUMBER;
        ln_exists_cnt                  NUMBER;          --Added for change 2.3
        l_chr_drop_ship_cust_name      VARCHAR2 (360); --Added for change 2.3 (Drop ship change)
        lv_freight_terms_code          VARCHAR2 (240); --Added for change 2.3(Freight terms change)
        -- Start of Change 3.0
        lv_custom_data_flag            VARCHAR2 (10);
        lv_cust_contact_phone          VARCHAR2 (150);
        lv_cust_email                  VARCHAR2 (150);
        lv_cust_pay_method             VARCHAR2 (240);
        lv_cust_reward_num             VARCHAR2 (240);
        ln_total_merch_value           NUMBER;
        ln_total_rewards_value         NUMBER;
        ln_total_promo_value           NUMBER;
        ln_total_ship_charges          NUMBER;
        ln_total_ship_discount         NUMBER;
        ln_total_tax                   NUMBER;
        ln_total_charges               NUMBER;
        ln_total_savings               NUMBER;
        lv_order_by_name               VARCHAR2 (100);
        lv_order_by_address1           VARCHAR2 (100);
        lv_order_by_address2           VARCHAR2 (100);
        lv_order_by_address3           VARCHAR2 (100);
        lv_order_by_city               VARCHAR2 (50);
        lv_order_by_state              VARCHAR2 (50);
        lv_order_by_country_code       VARCHAR2 (50);
        lv_order_by_zipcode            VARCHAR2 (12);
        lv_customer_sales_channel      VARCHAR2 (100);            --CCR0008657
        ln_cust_item_price             NUMBER;
        ln_split_from_line_id          oe_order_lines_all.split_from_line_id%TYPE;
        ln_ord_line_number             oe_order_lines_all.line_number%TYPE;
        -- End of Change 3.0

        --Begin CCR0008657
        lb_is_special_vas              BOOLEAN;
        --Labeling
        lv_gs1_format                  VARCHAR2 (100);
        lv_gs1_mc_panel                VARCHAR2 (30);
        lv_gs1_justification           VARCHAR2 (10);
        ln_gs1_side_offset             NUMBER;
        ln_gs1_bottom_offset           NUMBER;
        lv_print_cc                    VARCHAR2 (1);
        lv_cc_mc_panel                 VARCHAR2 (30);
        lv_cc_justification            VARCHAR2 (10);
        ln_cc_side_offset              NUMBER;
        ln_cc_bottom_offset            NUMBER;
        ln_mc_max_length               NUMBER;
        ln_mc_max_width                NUMBER;
        ln_mc_max_height               NUMBER;
        ln_mc_max_weight               NUMBER;
        ln_mc_min_length               NUMBER;
        ln_mc_min_width                NUMBER;
        ln_mc_min_height               NUMBER;
        ln_mc_min_weight               NUMBER;

        --Pack slip/routing
        lv_custom_ds_packslip_flag     VARCHAR2 (1);
        lv_custom_ds_email             VARCHAR2 (100);
        lv_custom_ds_phone             VARCHAR2 (100);
        lv_print_pack_slip             VARCHAR2 (1);
        lv_service_time_frame          VARCHAR2 (30);
        lv_call_in_sla                 VARCHAR2 (30);
        lv_tms_cutoff_time             VARCHAR2 (30);
        lv_routing_day1                VARCHAR2 (30);
        lv_scheduled_day1              VARCHAR2 (30);
        lv_routing_day2                VARCHAR2 (30);
        lv_scheduled_day2              VARCHAR2 (30);
        lv_back_to_back                VARCHAR2 (1);
        lv_tms_flag                    VARCHAR2 (1);
        lv_tms_url                     VARCHAR2 (1000);
        lv_tms_username                VARCHAR2 (100);
        lv_tms_password                VARCHAR2 (100);
        lv_routing_contact_name        VARCHAR2 (100);
        lv_routing_contact_phone       VARCHAR2 (100);
        lv_routing_contact_fax         VARCHAR2 (100);
        lv_routing_contact_email       VARCHAR2 (100);
        lv_parcel_ship_method          VARCHAR2 (100);
        ln_parcel_weight_limit         NUMBER;
        lv_parcel_dim_weight_flag      VARCHAR2 (1);
        ln_parcel_carton_limit         NUMBER;
        lv_ltl_ship_method             VARCHAR2 (100);
        ln_ltl_weight_limit            NUMBER;
        lv_ltl_dim_weight_flag         VARCHAR2 (1);
        ln_ltl_carton_limit            NUMBER;
        lv_ftl_ship_method             VARCHAR2 (100);
        ln_ftl_weight_limit            NUMBER;
        lv_ftl_dim_weight_flag         VARCHAR2 (1);
        ln_ftl_unit_limit              NUMBER;
        lv_ftl_pallet_flag             VARCHAR2 (1);
        lv_routing_notes               VARCHAR2 (2000);

        lv_assortment_id               VARCHAR2 (20);
        lv_assortment_qty              VARCHAR2 (5);

        lv_ds_customer_name            VARCHAR2 (50);
        lv_ds_contact_text             VARCHAR2 (1000);

        --Line fields
        lv_customer_gender_code        VARCHAR2 (30);
        lv_customer_department         VARCHAR2 (100);
        lv_customer_major_class        VARCHAR2 (100);
        lv_customer_sub_class          VARCHAR2 (100);
        lv_customer_box_id             VARCHAR2 (100);

        ln_param_value                 VARCHAR2 (400);
        lv_ticketing_instructions      VARCHAR2 (2000);
    --End CCR0008657
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Extracting Pick Ticket details started');
        l_chr_warehouse   := '-ZZ';
        l_num_order_num   := -999;
        l_chr_commit      := 'N';

        FOR c_org_rec IN c_org
        LOOP
            msg ('Warehouse ID: ' || c_org_rec.organization_id);
            gn_inv_org_id   := c_org_rec.organization_id;

            IF p_regenerate_xml = 'N'
            THEN
                FOR c_pick_hdr_rec IN c_pick_hdr (c_org_rec.organization_id)
                LOOP
                    msg ('Organization ID: ' || c_org_rec.organization_id);
                    msg ('Delivery ID: ' || c_pick_hdr_rec.delivery_id);

                    FOR c_pick_rec
                        IN c_pick_data (c_org_rec.organization_id,
                                        c_pick_hdr_rec.delivery_id)
                    LOOP
                        msg ('Warehouse: ' || c_pick_rec.warehouse_code);
                        msg (
                            'Pick Ticket Number: ' || c_pick_rec.order_number);
                        msg ('Line ID: ' || c_pick_rec.line_id);

                        --Begin CCR0008657
                        lb_is_special_vas     :=
                            get_sales_channel (c_pick_rec.order_header_id) =
                            'WHOLESALE';

                        -- AND NVL (c_pick_rec.special_vas, 'N') = 'Y';

                        IF lb_is_special_vas
                        THEN
                            msg ('Special VAS : Yes');
                        ELSE
                            msg ('Special VAS : No');
                        END IF;

                        --End CCR0008657


                        IF (l_chr_warehouse <> c_pick_rec.warehouse_code OR l_num_order_num <> c_pick_rec.order_number)
                        THEN
                            IF l_chr_commit = 'Y'
                            THEN
                                COMMIT;
                            /* commit previous header if that is already inserted */
                            --fnd_file.put_line (fnd_file.LOG, 'Commmit records for warehouse, order number: ' || l_chr_warehouse || ' : ' || l_num_order_num); --Commented for change 2.3
                            ELSIF l_num_order_num <> -999
                            THEN
                                ROLLBACK;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Rollback records for warehouse, order number: '
                                    || l_chr_warehouse
                                    || ' : '
                                    || l_num_order_num);
                            END IF;

                            l_chr_commit                   := 'Y';
                            /* this flag will be set to N if any insertion fails for this header */
                            --fnd_file.put_line (fnd_file.LOG, 'New header processing'); --Commented for change 2.3
                            /* records will be committed only when all records are successfully inserted for a given return order */

                            /* Initializations */
                            l_chr_warehouse                := c_pick_rec.warehouse_code;
                            l_num_order_num                := c_pick_rec.order_number;
                            l_num_count                    := 0;
                            l_chr_duty_terms               := NULL;
                            l_chr_duty_account_number      := NULL;
                            l_chr_charge_service_level     := NULL;
                            l_chr_saturday_delivery_flag   := 'N';
                            l_chr_return_phone             := NULL;
                            l_chr_duty_terms               := NULL;
                            l_chr_ecomm_phone              := NULL;
                            l_chr_ecomm_website            := NULL;
                            l_chr_newgistic_data           := NULL;
                            l_chr_usps_data                := NULL;
                            --fnd_file.put_line (fnd_file.LOG, 'Warehouse:' || l_chr_warehouse); --Commented for change 2.3
                            --fnd_file.put_line (fnd_file.LOG, 'Pick Ticket number:' || l_num_order_num); --Commented for change 2.3
                            --fnd_file.put_line(fnd_file.LOG, 'Start of Updating to OBSOLETE status if pick ticket already exists');
                            msg (
                                'Start of Updating to OBSOLETE status if pick ticket already exists');

                            --Code added for change 2.3 --START
                            --Check if the orders exists in the staging table with PROCESSED status
                            SELECT COUNT (*)
                              INTO ln_exists_cnt
                              FROM xxont_pick_intf_hdr_stg
                             WHERE     1 = 1
                                   AND order_number =
                                       TO_CHAR (l_num_order_num) -- Added TO_CHAR for CCR0009119
                                   --AND warehouse_code = l_chr_warehouse
                                   --AND process_status <> gc_obsolete_status --'OBSOLETE' --Commented for change 2.1
                                   --AND process_status NOT IN (gc_obsolete_status, gc_inprocess_status) --Added for change 2.1 --Commented for change 2.3
                                   AND process_status = gc_processed_status --Added for change 2.3
                                                                           ;

                            --Code added for change 2.3 --END

                            --Update the status only if order number exists with processed status
                            --Added ln_exists_cnt if for change 2.3
                            --fnd_file.put_line (fnd_file.LOG, 'Updation of Staging\Log Tables - ln_exists_cnt :'||ln_exists_cnt);  --4.3
                            IF ln_exists_cnt > 0
                            THEN
                                --If the pick ticket/Delivery already exists and it is not OBSOLETE, then mark it as OBSOLETE
                                UPDATE xxont_pick_intf_hdr_stg
                                   SET process_status = gc_obsolete_status, --'OBSOLETE',
                                                                            last_update_date = SYSDATE, last_updated_by = g_num_user_id,
                                       last_update_login = g_num_login_id
                                 WHERE     1 = 1
                                       AND order_number =
                                           TO_CHAR (l_num_order_num) -- Added TO_CHAR for CCR0009119
                                       --                            AND warehouse_code = l_chr_warehouse --Commented for change 2.3 as the Warehouse is constant
                                       --AND process_status <> gc_obsolete_status --'OBSOLETE' --Commented for change 2.1
                                       --AND process_status NOT IN (gc_obsolete_status, gc_inprocess_status) --Added for change 2.1 --Commented for change 2.3
                                       AND process_status =
                                           gc_processed_status --Added for change 2.3
                                                              ;

                                l_num_count   := SQL%ROWCOUNT;

                                --If the pick ticket/Delivery already exists and it is not OBSOLETE, then mark it as OBSOLETE
                                UPDATE xxont_pick_intf_line_stg
                                   SET process_status = gc_obsolete_status, --'OBSOLETE',
                                                                            last_update_date = SYSDATE, last_updated_by = g_num_user_id,
                                       last_update_login = g_num_login_id
                                 WHERE     1 = 1
                                       AND order_number =
                                           TO_CHAR (l_num_order_num) -- Added TO_CHAR for CCR0009119
                                       --                            AND warehouse_code = l_chr_warehouse --Commented for change 2.3 as the Warehouse is constant
                                       --AND process_status <> gc_obsolete_status --'OBSOLETE' --Commented for change 2.1
                                       --AND process_status NOT IN (gc_obsolete_status, gc_inprocess_status) --Added for change 2.1 --Commented for change 2.3
                                       AND process_status =
                                           gc_processed_status --Added for change 2.3
                                                              ;

                                --If the pick ticket/Delivery already exists and it is not OBSOLETE, then mark it as OBSOLETE
                                UPDATE xxont_pick_intf_cmt_hdr_stg
                                   SET process_status = gc_obsolete_status, --'OBSOLETE',
                                                                            last_update_date = SYSDATE, last_updated_by = g_num_user_id,
                                       last_update_login = g_num_login_id
                                 WHERE     1 = 1
                                       AND order_number =
                                           TO_CHAR (l_num_order_num) -- Added TO_CHAR for CCR0009119
                                       --                            AND warehouse_code = l_chr_warehouse --Commented for change 2.3 as the Warehouse is constant
                                       --AND process_status <> gc_obsolete_status --'OBSOLETE' --Commented for change 2.1
                                       --AND process_status NOT IN (gc_obsolete_status, gc_inprocess_status) --Added for change 2.1 --Commented for change 2.3
                                       AND process_status =
                                           gc_processed_status --Added for change 2.3
                                                              ;

                                --If the pick ticket/Delivery already exists and it is not OBSOLETE, then mark it as OBSOLETE
                                UPDATE xxont_pick_intf_cmt_line_stg
                                   SET process_status = gc_obsolete_status, --'OBSOLETE',
                                                                            last_update_date = SYSDATE, last_updated_by = g_num_user_id,
                                       last_update_login = g_num_login_id
                                 WHERE     1 = 1
                                       AND order_number =
                                           TO_CHAR (l_num_order_num) -- Added TO_CHAR for CCR0009119
                                       --                            AND warehouse_code = l_chr_warehouse --Commented for change 2.3 as the Warehouse is constant
                                       --AND process_status <> gc_obsolete_status --'OBSOLETE' --Commented for change 2.1
                                       --AND process_status NOT IN (gc_obsolete_status, gc_inprocess_status) --Added for change 2.1 --Commented for change 2.3
                                       AND process_status =
                                           gc_processed_status --Added for change 2.3
                                                              ;

                                --If the pick ticket/Delivery already exists and it is not OBSOLETE, then mark it as OBSOLETE
                                UPDATE xxont_pick_intf_vas_hdr_stg
                                   SET process_status = gc_obsolete_status, --'OBSOLETE',
                                                                            last_update_date = SYSDATE, last_updated_by = g_num_user_id,
                                       last_update_login = g_num_login_id
                                 WHERE     1 = 1
                                       AND order_number =
                                           TO_CHAR (l_num_order_num) -- Added TO_CHAR for CCR0009119
                                       --                            AND warehouse_code = l_chr_warehouse --Commented for change 2.3 as the Warehouse is constant
                                       --AND process_status <> gc_obsolete_status --'OBSOLETE' --Commented for change 2.1
                                       --AND process_status NOT IN (gc_obsolete_status, gc_inprocess_status) --Added for change 2.1 --Commented for change 2.3
                                       AND process_status =
                                           gc_processed_status --Added for change 2.3
                                                              ;

                                --If the pick ticket/Delivery already exists and it is not OBSOLETE, then mark it as OBSOLETE
                                UPDATE xxont_pick_intf_vas_line_stg
                                   SET process_status = gc_obsolete_status, --'OBSOLETE',
                                                                            last_update_date = SYSDATE, last_updated_by = g_num_user_id
                                 WHERE     1 = 1
                                       AND order_number =
                                           TO_CHAR (l_num_order_num) -- Added TO_CHAR for CCR0009119
                                       --                            AND warehouse_code = l_chr_warehouse --Commented for change 2.3 as the Warehouse is constant
                                       --AND process_status <> gc_obsolete_status --'OBSOLETE' --Commented for change 2.1
                                       --AND process_status NOT IN (gc_obsolete_status, gc_inprocess_status) --Added for change 2.1 --Commented for change 2.3
                                       AND process_status =
                                           gc_processed_status; --Added for change 2.3

                                --Begin CCR0008657
                                UPDATE xxdo.XXD_ONT_PK_INTF_P_HDR_STG_T
                                   SET process_status = gc_obsolete_status, last_update_date = SYSDATE, last_updated_by = g_num_user_id
                                 WHERE     1 = 1
                                       AND order_number =
                                           TO_CHAR (l_num_order_num)
                                       AND process_status =
                                           gc_processed_status;

                                UPDATE xxdo.XXD_ONT_PK_INTF_P_LN_STG_T
                                   SET process_status = gc_obsolete_status, last_update_date = SYSDATE, last_updated_by = g_num_user_id
                                 WHERE     1 = 1
                                       AND order_number =
                                           TO_CHAR (l_num_order_num)
                                       AND process_status =
                                           gc_processed_status;

                                --End CCR0008657

                                --Start changes for 4.3
                                --Updation of Log Tables with status 'OBSOLETE'
                                --If the pick ticket/Delivery already exists and it is not OBSOLETE, then marking as OBSOLETE
                                UPDATE xxdo.xxont_pick_intf_hdr_stg_log
                                   SET process_status = gc_obsolete_status, --'OBSOLETE',
                                                                            last_update_date = SYSDATE, last_updated_by = g_num_user_id,
                                       last_update_login = g_num_login_id
                                 WHERE     1 = 1
                                       AND order_number =
                                           TO_CHAR (l_num_order_num)
                                       AND process_status =
                                           gc_processed_status;

                                UPDATE xxdo.xxont_pick_intf_line_stg_log
                                   SET process_status = gc_obsolete_status, last_update_date = SYSDATE, last_updated_by = g_num_user_id,
                                       last_update_login = g_num_login_id
                                 WHERE     1 = 1
                                       AND order_number =
                                           TO_CHAR (l_num_order_num)
                                       AND process_status =
                                           gc_processed_status;

                                UPDATE xxdo.xxont_pick_intf_cmt_hdr_s_log
                                   SET process_status = gc_obsolete_status, last_update_date = SYSDATE, last_updated_by = g_num_user_id,
                                       last_update_login = g_num_login_id
                                 WHERE     1 = 1
                                       AND order_number =
                                           TO_CHAR (l_num_order_num)
                                       AND process_status =
                                           gc_processed_status;

                                UPDATE xxdo.xxont_pick_intf_cmt_line_s_log
                                   SET process_status = gc_obsolete_status, last_update_date = SYSDATE, last_updated_by = g_num_user_id,
                                       last_update_login = g_num_login_id
                                 WHERE     1 = 1
                                       AND order_number =
                                           TO_CHAR (l_num_order_num)
                                       AND process_status =
                                           gc_processed_status;

                                UPDATE xxdo.xxont_pick_intf_vas_hdr_s_log
                                   SET process_status = gc_obsolete_status, last_update_date = SYSDATE, last_updated_by = g_num_user_id,
                                       last_update_login = g_num_login_id
                                 WHERE     1 = 1
                                       AND order_number =
                                           TO_CHAR (l_num_order_num)
                                       AND process_status =
                                           gc_processed_status;

                                UPDATE xxdo.xxont_pick_intf_vas_line_s_log
                                   SET process_status = gc_obsolete_status, last_update_date = SYSDATE, last_updated_by = g_num_user_id
                                 WHERE     1 = 1
                                       AND order_number =
                                           TO_CHAR (l_num_order_num)
                                       AND process_status =
                                           gc_processed_status;

                                UPDATE xxdo.xxont_pick_intf_serial_stg_log
                                   SET process_status = gc_obsolete_status, last_update_date = SYSDATE, last_updated_by = g_num_user_id
                                 WHERE     1 = 1
                                       AND order_number =
                                           TO_CHAR (l_num_order_num)
                                       AND process_status =
                                           gc_processed_status;
                            --End changes for 4.3
                            END IF;    --Added ln_exists_cnt if for change 2.3

                            --fnd_file.put_line(fnd_file.LOG, 'End of Updating to OBSOLETE status if pick ticket already exists');
                            msg (
                                'End of Updating to OBSOLETE status if pick ticket already exists');
                            msg ('Inserting new header record');

                            --Getting the header id for the pick interface header staging table from sequence
                            BEGIN
                                SELECT xxdo_pick_intf_hdr_seq.NEXTVAL
                                  INTO l_num_stg_header_id
                                  FROM DUAL;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Error while getting next value from sequence XXDO_PICK_INTF_HDR_SEQ. Error is: '
                                        || SQLERRM);
                                    l_num_stg_header_id   := NULL;
                            END;

                            BEGIN
                                SELECT MIN (oola.request_date) request_date, MAX (TO_DATE (oola.attribute1, 'YYYY/MM/DD HH24:MI:SS')) cancel_date, MIN (wnd.creation_date) prepick_date
                                  INTO ld_request_date, ld_cancel_date, ld_prepick_date
                                  FROM apps.wsh_new_deliveries wnd, apps.wsh_delivery_assignments wda, apps.wsh_delivery_details wdd,
                                       apps.oe_order_lines_all oola
                                 WHERE     1 = 1
                                       AND wnd.delivery_id =
                                           c_pick_hdr_rec.delivery_id
                                       AND wnd.delivery_id = wda.delivery_id
                                       AND wda.delivery_detail_id =
                                           wdd.delivery_detail_id
                                       AND wdd.source_code = 'OE'
                                       AND wdd.source_line_id = oola.line_id
                                       AND wdd.organization_id =
                                           oola.ship_from_org_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    ld_cancel_date    := NULL;
                                    ld_prepick_date   := NULL;
                                    ld_request_date   := NULL;
                            END;

                            --Getting the Ship to phone number
                            BEGIN
                                SELECT raw_phone_number
                                  INTO l_chr_ship_phone
                                  FROM hz_contact_points hcp
                                 WHERE     1 = 1
                                       AND hcp.owner_table_name =
                                           'HZ_PARTY_SITES'
                                       AND owner_table_id =
                                           c_pick_rec.ship_cust_acct_site_id
                                       AND contact_point_type = 'PHONE'
                                       AND primary_flag = 'Y'
                                       AND ROWNUM = 1;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_chr_ship_phone   := NULL;
                            END;

                            --Getting Ship to email address
                            BEGIN
                                SELECT email_address
                                  INTO l_chr_ship_email
                                  FROM hz_contact_points hcp
                                 WHERE     1 = 1
                                       AND hcp.owner_table_name =
                                           'HZ_PARTY_SITES'
                                       AND owner_table_id =
                                           c_pick_rec.ship_cust_acct_site_id
                                       AND contact_point_type = 'EMAIL'
                                       AND primary_flag = 'Y'
                                       AND ROWNUM = 1;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_chr_ship_email   := NULL;
                            END;

                            --Getting the Bill to phone number
                            BEGIN
                                SELECT raw_phone_number
                                  INTO l_chr_bill_phone
                                  FROM hz_contact_points hcp
                                 WHERE     1 = 1
                                       AND hcp.owner_table_name =
                                           'HZ_PARTY_SITES'
                                       AND owner_table_id =
                                           c_pick_rec.bill_cust_acct_site_id
                                       AND contact_point_type = 'PHONE'
                                       AND primary_flag = 'Y'
                                       AND ROWNUM = 1;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_chr_bill_phone   := NULL;
                            END;

                            --Getting Bill to email address
                            BEGIN
                                SELECT email_address
                                  INTO l_chr_bill_email
                                  FROM hz_contact_points hcp
                                 WHERE     1 = 1
                                       AND hcp.owner_table_name =
                                           'HZ_PARTY_SITES'
                                       AND owner_table_id =
                                           c_pick_rec.bill_cust_acct_site_id
                                       AND contact_point_type = 'EMAIL'
                                       AND primary_flag = 'Y'
                                       AND ROWNUM = 1;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_chr_bill_email   := NULL;
                            END;

                            --Custom drop ship packing slip
                            BEGIN
                                lv_custom_ds_packslip_flag   := NULL;
                                lv_custom_ds_email           := NULL;
                                lv_custom_ds_phone           := NULL;

                                SELECT custom_dropship_packslip_flag, custom_dropship_email, custom_dropship_phone_num
                                  INTO lv_custom_ds_packslip_flag, lv_custom_ds_email, lv_custom_ds_phone
                                  FROM XXD_ONT_CUSTOMER_HEADER_INFO_T
                                 WHERE cust_account_id =
                                       c_pick_rec.cust_account_id;

                                IF NVL (lv_custom_ds_packslip_flag, 'N') =
                                   'Y'
                                THEN
                                    INSERT INTO xxont_pick_intf_vas_hdr_stg (
                                                    warehouse_code,
                                                    order_number,
                                                    vas_code,
                                                    vas_description,
                                                    vas_item_number,
                                                    vas_label_type,
                                                    process_status,
                                                    request_id,
                                                    creation_date,
                                                    created_by,
                                                    last_update_date,
                                                    last_updated_by,
                                                    last_update_login,
                                                    source_type,
                                                    SOURCE,
                                                    destination,
                                                    record_id,
                                                    vas_free_text,
                                                    vas_label_format)
                                             VALUES (
                                                        SUBSTR (
                                                            c_pick_rec.warehouse_code,
                                                            1,
                                                            10),
                                                        SUBSTR (
                                                            c_pick_rec.order_number,
                                                            1,
                                                            30),
                                                        SUBSTR ('B055',
                                                                1,
                                                                20),
                                                        SUBSTR (
                                                            'Print Custom Drop Ship Packing Slip',
                                                            1,
                                                            250),
                                                        NULL,
                                                        NULL,
                                                        gc_new_status,
                                                        g_num_request_id,
                                                        SYSDATE,
                                                        g_num_user_id,
                                                        SYSDATE,
                                                        g_num_user_id,
                                                        g_num_login_id,
                                                        'ORDER',
                                                        p_source,
                                                        p_dest,
                                                        xxdo_pick_intf_vas_hdr_seq.NEXTVAL,
                                                        'B055 Comments', --TODO : Accurate description
                                                        c_pick_rec.vas_label_format);
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_custom_ds_packslip_flag   := NULL;
                                    lv_custom_ds_email           := NULL;
                                    lv_custom_ds_phone           := NULL;
                            END;

                            /*Commented per CCR0008657
                            l_num_count := 0;
                            l_num_drop_ship_count := 0;
                            l_chr_drop_cust_contact := NULL;
                            l_chr_drop_cust_name := NULL;

                            --Getting Drop Ship Details
                            BEGIN
                                SELECT 1               drop_ship_count,
                                       description     drop_ship_contact,
                                       meaning         drop_ship_cust_name
                                  INTO l_num_drop_ship_count,
                                       l_chr_drop_cust_contact,
                                       l_chr_drop_cust_name
                                  FROM fnd_lookup_values
                                 WHERE     1 = 1
                                       AND lookup_type =
                                           'XXDO_DTC_PACKSLIP_DATA'
                                       AND LANGUAGE = 'US'
                                       AND lookup_code =
                                           c_pick_rec.customer_code
                                       AND enabled_flag = 'Y'
                                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                       start_date_active,
                                                                         SYSDATE
                                                                       - 1)
                                                               AND NVL (
                                                                       end_date_active,
                                                                         SYSDATE
                                                                       + 1);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_num_drop_ship_count := 0;
                                    l_chr_drop_cust_contact := NULL;
                                    l_chr_drop_cust_name := NULL;
                            END;
*/

                            --IF c_pick_rec.order_type IN ('Consumer Direct - US')  -- Commented as per change of ver 2.6
                            --START Added as per ver 2.6
                            IF c_pick_rec.order_type IN
                                   ('Consumer Direct - US', '3rd Party eCommerce - US')
                            --END Added as per ver 2.6
                            THEN
                                BEGIN
                                    SELECT hcas.cust_acct_site_id, hcsu.LOCATION, hl.address1,
                                           hl.address2, hl.address3, hl.city,
                                           NVL (hl.state, hl.province), hl.postal_code, hl.country,
                                           hp.party_name
                                      INTO c_pick_rec.return_cust_acct_site_id, c_pick_rec.return_code, c_pick_rec.return_address1,
                                           c_pick_rec.return_address2, c_pick_rec.return_address3, c_pick_rec.return_city,
                                           c_pick_rec.return_state, c_pick_rec.return_postal_code, c_pick_rec.return_country,
                                           l_chr_drop_ship_cust_name
                                      FROM hz_parties hp, hz_cust_accounts hca, hz_cust_acct_sites_all hcas,
                                           hz_cust_site_uses_all hcsu, hz_party_sites hps, hz_locations hl
                                     WHERE     1 = 1
                                           AND hp.party_name =
                                               c_pick_rec.customer_name
                                           AND hp.party_id = hca.party_id
                                           AND hca.cust_account_id =
                                               hcas.cust_account_id
                                           AND hcas.cust_acct_site_id =
                                               hcsu.cust_acct_site_id
                                           AND hcsu.site_use_code = 'SHIP_TO'
                                           AND hcsu.primary_flag = 'Y'
                                           AND hcas.party_site_id =
                                               hps.party_site_id
                                           AND hps.location_id =
                                               hl.location_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'Return address could not be derived for customer : '
                                            || c_pick_rec.customer_name);
                                END;

                                BEGIN
                                    lv_ds_customer_name   := NULL;
                                    lv_ds_contact_text    := NULL;

                                    SELECT NVL (hdr.dropship_packslip_display_name, hzp.party_name), hdr.dropship_packslip_message
                                      INTO lv_ds_customer_name, lv_ds_contact_text
                                      FROM xxd_ont_customer_header_info_t hdr, hz_cust_accounts hzca, hz_parties hzp
                                     WHERE     hdr.cust_account_id =
                                               c_pick_rec.cust_account_id
                                           AND hdr.cust_account_id =
                                               hzca.cust_account_id
                                           AND hzca.party_id = hzp.party_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        NULL;
                                END;

                                IF c_pick_rec.return_cust_acct_site_id
                                       IS NOT NULL
                                THEN
                                    BEGIN
                                        SELECT raw_phone_number
                                          INTO l_chr_return_phone
                                          FROM hz_contact_points hcp
                                         WHERE     1 = 1
                                               AND hcp.owner_table_name =
                                                   'HZ_PARTY_SITES'
                                               AND owner_table_id =
                                                   c_pick_rec.return_cust_acct_site_id
                                               AND contact_point_type =
                                                   'PHONE'
                                               AND primary_flag = 'Y'
                                               AND ROWNUM = 1;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            l_chr_return_phone   := NULL;
                                    END;
                                END IF;
                            END IF;

                            l_chr_order_type               := 'WHOLESALE';
                            l_chr_order_source             := NULL;

                            BEGIN
                                SELECT NAME order_source
                                  INTO l_chr_order_source
                                  FROM oe_order_sources
                                 WHERE     1 = 1
                                       AND order_source_id =
                                           c_pick_rec.order_source_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Unable to derive order source name for ID: '
                                        || c_pick_rec.order_source_id);
                            END;

                            IF l_chr_order_source = 'Flagstaff'
                            THEN
                                l_chr_order_type   := 'ECOM';
                            ELSIF l_chr_order_source = 'Retail'
                            THEN
                                l_chr_order_type   := 'RETAIL';
                            ELSIF l_chr_order_source = 'Internal'
                            THEN
                                l_chr_order_type   := 'TRANSFER';
                            ELSIF c_pick_rec.order_type =
                                  'Consumer Direct - US'
                            THEN
                                l_chr_order_type   := 'DROPSHIP';
                            --START Added as per ver 2.6
                            ELSIF c_pick_rec.order_type =
                                  '3rd Party eCommerce - US'
                            THEN
                                l_chr_order_type   := 'DROPSHIP';
                            --END Added as per ver 2.6
                            ELSIF c_pick_rec.order_type = 'Cross Dock - US'
                            THEN
                                l_chr_order_type   := 'CROSSDOCK';
                            END IF;


                            IF (l_chr_order_type = 'ECOM' AND c_pick_rec.ship_country = 'CA')
                            THEN
                                l_chr_duty_terms   := 'COLLECT';
                            ELSE
                                l_chr_duty_terms   := 'PREPAID';
                            END IF;

                            IF l_chr_order_type = 'ECOM'
                            THEN
                                /*Ecomm phone amd url columns*/
                                BEGIN
                                    SELECT flv.meaning, flv.description
                                      INTO l_chr_ecomm_phone, l_chr_ecomm_website
                                      FROM fnd_lookup_values flv
                                     WHERE     1 = 1
                                           AND flv.lookup_type =
                                               'XXDO_ECOM_INVOICE_BRAND_US'
                                           AND flv.LANGUAGE = 'US'
                                           AND flv.lookup_code =
                                               c_pick_rec.brand_code;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        l_chr_ecomm_phone     := NULL;
                                        l_chr_ecomm_website   := NULL;
                                END;

                                /*Ecomm newgistics data columns*/
                                BEGIN
                                    SELECT flv.meaning, flv.description
                                      INTO l_chr_newgistic_data, l_chr_usps_data
                                      FROM fnd_lookup_values flv
                                     WHERE     1 = 1
                                           AND flv.lookup_type =
                                               'XXDO_ECOM_NEWGISTICS_DATA'
                                           AND flv.LANGUAGE = 'US'
                                           AND flv.enabled_flag = 'Y'
                                           AND SYSDATE BETWEEN NVL (
                                                                   flv.start_date_active,
                                                                     SYSDATE
                                                                   - 1)
                                                           AND NVL (
                                                                   flv.end_date_active,
                                                                     SYSDATE
                                                                   + 1)
                                           AND flv.lookup_code =
                                               c_pick_rec.brand_code;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        l_chr_newgistic_data   := NULL;
                                        l_chr_usps_data        := NULL;
                                END;

                                IF l_chr_newgistic_data IS NOT NULL
                                THEN
                                    l_chr_newgistic_data   :=
                                           '7'
                                        || '25'
                                        || '00'
                                        || LPAD (
                                               NVL (
                                                   SUBSTR (
                                                       c_pick_rec.ship_postal_code,
                                                       1,
                                                       5),
                                                   '0'),
                                               5,
                                               '0')
                                        || '01'
                                        || l_chr_newgistic_data
                                        || '0';

                                    IF (c_pick_rec.normal_or_amazon LIKE '%AMZN%' OR c_pick_rec.order_type LIKE '%US-AMZN')
                                    THEN
                                        l_chr_newgistic_data   :=
                                            l_chr_newgistic_data || '2';
                                        l_chr_newgistic_data   :=
                                               l_chr_newgistic_data
                                            || LPAD (
                                                   NVL (
                                                       SUBSTR (
                                                           REPLACE (
                                                               c_pick_rec.ref_cust_po_number,
                                                               '-',
                                                               NULL),
                                                           1,
                                                           17),
                                                       '0'),
                                                   17,
                                                   '0');
                                    ELSE
                                        l_chr_newgistic_data   :=
                                            l_chr_newgistic_data || '1';
                                        l_chr_newgistic_data   :=
                                               l_chr_newgistic_data
                                            || LPAD (
                                                   NVL (
                                                       SUBSTR (
                                                           REPLACE (
                                                               c_pick_rec.ref_cust_po_number,
                                                               '-',
                                                               NULL),
                                                           1,
                                                           8),
                                                       '0'),
                                                   8,
                                                   '0');
                                    END IF;
                                END IF;

                                IF l_chr_usps_data IS NOT NULL
                                THEN
                                    SELECT '420' || '56901' || '92' || '02' || l_chr_usps_data || LPAD (REVERSE (SUBSTR (REVERSE (TO_CHAR (c_pick_rec.order_header_id + 2000000)), 1, 8)), 8, '0')
                                      INTO l_chr_usps_data
                                      FROM DUAL;
                                END IF;

                                --CCR0009572 Addition for Hubbox
                                BEGIN
                                    SELECT DISTINCT
                                           SUBSTR (attribute_value, 1, 30)
                                      INTO l_chr_dc_number --This is the field in the pick ticket stg table to be used
                                      FROM apps.xxdoec_order_attribute
                                     WHERE     order_header_id =
                                               c_pick_rec.order_header_id
                                           AND attribute_type =
                                               'DWROUTINGTYPE';
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        l_chr_dc_number   := NULL;
                                END;
                            ELSE
                                --All other order types
                                l_chr_dc_number   :=
                                    SUBSTR (c_pick_rec.dc_number, 1, 30);
                            --End CCR0009572
                            END IF;

                            --l_chr_charge_service_level := c_pick_rec.service_level; --Commented for HPQC Defect # 1035 (Change 2.0)
                            BEGIN
                                SELECT --NVL(attribute1, c_pick_rec.service_level), --Commented for HPQC Defect # 1035 (Change 2.0)
                                       attribute1, --Added for HPQC Defect # 1035 (Change 2.0)
                                                   NVL (attribute2, 'N')
                                  INTO l_chr_charge_service_level, l_chr_saturday_delivery_flag
                                  FROM wsh_carrier_services
                                 WHERE     1 = 1
                                       AND carrier_id = c_pick_rec.carrier_id
                                       AND ship_method_code =
                                           c_pick_rec.service_level_code
                                       AND ROWNUM = 1;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    --l_chr_charge_service_level := c_pick_rec.service_level; --Commented for HPQC Defect # 1035 (Change 2.0)
                                    l_chr_charge_service_level     := NULL;
                                    --Added for HPQC Defect # 1035 (Change 2.0)
                                    l_chr_saturday_delivery_flag   := 'N';
                            END;

                            --START of change 2.4
                            --Reverting the changes done with version 2.3 for freight terms for change 2.4
                            /*
                            --Added for change 2.3 for frieght terms - START
                            BEGIN
                               IF c_pick_rec.order_type = 'Consumer Direct - US'
                               THEN
                                  --lv_freight_terms_code := '3RD_PARTY'; --Commented for change 2.4
                                  lv_freight_terms_code := '3RDPARTY';  --Added for change 2.4(Removed Underscore which is incorrect)

                               ELSIF c_pick_rec.freight_account IS NOT NULL AND
                                     c_pick_rec.order_type <> 'Consumer Direct - US'
                               THEN
                                  lv_freight_terms_code := 'COLLECT';
                               ELSE
                                  BEGIN
                                     SELECT description
                                       INTO lv_freight_terms_code
                                       FROM fnd_lookup_values
                                      WHERE 1=1
                                        AND language = 'US'
                                        AND lookup_type = 'XXD_WMS_FREIGHT_CODES'
                                        AND meaning = c_pick_rec.freight_terms_code
                                     ;
                                  EXCEPTION
                                     WHEN NO_DATA_FOUND THEN
                                        lv_freight_terms_code := 'PREPAID';
                                     WHEN OTHERS THEN
                                        lv_freight_terms_code := 'PREPAID';
                                  END;
                               END IF;
                            END;
                            --Added for change 2.3 for frieght terms - END
                            */
                            --END of change 2.4

                            -- Start of Change 3.0

                            -- Commented by Krishna L, We should get data from custom MDM. We are already fetching the data above from custom MDM
                            /*lv_custom_data_flag := NULL;
                            lv_cust_contact_phone := NULL;
                            lv_cust_email := NULL;

                            BEGIN
                               SELECT attribute1, attribute2, attribute3
                                 INTO lv_custom_data_flag,
                                      lv_cust_contact_phone,
                                      lv_cust_email
                                 FROM fnd_lookup_values
                                WHERE     1 = 1
                                      AND lookup_type = 'XXDO_DTC_PACKSLIP_DATA'
                                      AND LANGUAGE = 'US'
                                      AND lookup_code = c_pick_rec.customer_code
                                      AND enabled_flag = 'Y'
                                      AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                     start_date_active,
                                                                     SYSDATE - 1)
                                                              AND NVL (
                                                                     end_date_active,
                                                                     SYSDATE + 1);
                            EXCEPTION
                               WHEN OTHERS
                               THEN
                                  lv_custom_data_flag := NULL;
                                  lv_cust_contact_phone := NULL;
                                  lv_cust_email := NULL;
                            END;*/

                            lv_cust_pay_method             := NULL;
                            lv_cust_reward_num             := NULL;
                            ln_total_merch_value           := NULL;
                            ln_total_rewards_value         := NULL;
                            ln_total_promo_value           := NULL;
                            ln_total_ship_charges          := NULL;
                            ln_total_ship_discount         := NULL;
                            ln_total_tax                   := NULL;
                            ln_total_charges               := NULL;
                            ln_total_savings               := NULL;
                            lv_order_by_name               := NULL;
                            lv_order_by_address1           := NULL;
                            lv_order_by_address2           := NULL;
                            lv_order_by_address3           := NULL;
                            lv_order_by_city               := NULL;
                            lv_order_by_state              := NULL;
                            lv_order_by_country_code       := NULL;
                            lv_order_by_zipcode            := NULL;
                            lv_customer_sales_channel      := NULL; --CCR0008657

                            --IF NVL (lv_custom_data_flag, 'N') = 'Y'
                            IF NVL (lv_custom_ds_packslip_flag, 'N') = 'Y'
                            THEN
                                BEGIN
                                    SELECT cust_ord_hdr.customer_payment_method, cust_ord_hdr.customer_reward_number, cust_ord_hdr.total_merchandise_value,
                                           cust_ord_hdr.total_rewards_value, cust_ord_hdr.total_promo_value, cust_ord_hdr.total_shipping_charges,
                                           cust_ord_hdr.total_shipping_discount, cust_ord_hdr.total_tax, cust_ord_hdr.total_charge,
                                           cust_ord_hdr.total_savings, cust_ord_hdr.order_by_name, cust_ord_hdr.order_by_address1,
                                           cust_ord_hdr.order_by_address2, cust_ord_hdr.order_by_address3, cust_ord_hdr.order_by_city,
                                           cust_ord_hdr.order_by_state, cust_ord_hdr.order_by_country, cust_ord_hdr.order_by_zipcode
                                      INTO lv_cust_pay_method, lv_cust_reward_num, ln_total_merch_value, ln_total_rewards_value,
                                                             ln_total_promo_value, ln_total_ship_charges, ln_total_ship_discount,
                                                             ln_total_tax, ln_total_charges, ln_total_savings,
                                                             lv_order_by_name, lv_order_by_address1, lv_order_by_address2,
                                                             lv_order_by_address3, lv_order_by_city, lv_order_by_state,
                                                             lv_order_by_country_code, lv_order_by_zipcode
                                      FROM apps.oe_order_headers_all ooha, apps.wsh_new_deliveries wnd, xxdo.xxd_ont_cust_ord_hdr_dtls_t cust_ord_hdr
                                     WHERE     1 = 1
                                           AND ooha.header_id =
                                               wnd.source_header_id
                                           AND wnd.delivery_id =
                                               c_pick_rec.header_id
                                           AND cust_ord_hdr.orig_sys_document_ref =
                                               ooha.orig_sys_document_ref
                                           AND cust_ord_hdr.org_id =
                                               ooha.org_id
                                           AND cust_ord_hdr.customer_po_number =
                                               ooha.cust_po_number;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        lv_cust_pay_method         := NULL;
                                        lv_cust_reward_num         := NULL;
                                        ln_total_merch_value       := NULL;
                                        ln_total_rewards_value     := NULL;
                                        ln_total_promo_value       := NULL;
                                        ln_total_ship_charges      := NULL;
                                        ln_total_ship_discount     := NULL;
                                        ln_total_tax               := NULL;
                                        ln_total_charges           := NULL;
                                        ln_total_savings           := NULL;
                                        lv_order_by_name           := NULL;
                                        lv_order_by_address1       := NULL;
                                        lv_order_by_address2       := NULL;
                                        lv_order_by_address3       := NULL;
                                        lv_order_by_city           := NULL;
                                        lv_order_by_state          := NULL;
                                        lv_order_by_country_code   := NULL;
                                        lv_order_by_zipcode        := NULL;
                                END;
                            END IF;

                            --Begin CCR0008657
                            IF lb_is_special_vas
                            THEN
                                BEGIN
                                    SELECT cust_ord_hdr.customer_sales_channel
                                      INTO lv_customer_sales_channel
                                      FROM apps.oe_order_headers_all ooha, apps.wsh_new_deliveries wnd, xxdo.xxd_ont_cust_ord_hdr_dtls_t cust_ord_hdr
                                     WHERE     1 = 1
                                           AND ooha.header_id =
                                               wnd.source_header_id
                                           AND wnd.delivery_id =
                                               c_pick_rec.header_id
                                           AND cust_ord_hdr.orig_sys_document_ref =
                                               ooha.orig_sys_document_ref
                                           AND cust_ord_hdr.org_id =
                                               ooha.org_id
                                           AND cust_ord_hdr.customer_po_number =
                                               ooha.cust_po_number;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        lv_customer_sales_channel   := NULL;
                                END;

                                --Get label info
                                BEGIN
                                    lv_gs1_mc_panel        := NULL;
                                    lv_gs1_justification   := NULL;
                                    ln_gs1_side_offset     := NULL;
                                    ln_gs1_bottom_offset   := NULL;
                                    lv_print_cc            := NULL;
                                    lv_cc_mc_panel         := NULL;
                                    lv_cc_justification    := NULL;
                                    ln_cc_side_offset      := NULL;
                                    ln_cc_bottom_offset    := NULL;
                                    ln_mc_max_length       := NULL;
                                    ln_mc_max_width        := NULL;
                                    ln_mc_max_height       := NULL;
                                    ln_mc_max_weight       := NULL;
                                    ln_mc_min_length       := NULL;
                                    ln_mc_min_width        := NULL;
                                    ln_mc_min_height       := NULL;
                                    ln_mc_min_weight       := NULL;

                                    --First select ship-to record
                                    SELECT NVL (st.gs1_mc_panel, h.gs1_mc_panel), NVL (st.gs1_justification, h.gs1_justification), NVL (st.gs1_side_offset, h.gs1_side_offset),
                                           NVL (st.gs1_bottom_offset, h.gs1_bottom_offset), NVL (st.print_cc, h.print_cc), NVL (st.cc_mc_panel, h.cc_mc_panel),
                                           NVL (st.cc_justification, h.cc_justification), NVL (st.cc_side_offset, h.cc_side_offset), NVL (st.cc_bottom_offset, h.cc_bottom_offset),
                                           --Min/Max Dims not in ST record
                                           h.mc_max_length, h.mc_max_width, h.mc_max_height,
                                           h.mc_max_weight, h.mc_min_length, h.mc_min_width,
                                           h.mc_min_height, h.mc_min_weight
                                      INTO lv_gs1_mc_panel, lv_gs1_justification, ln_gs1_side_offset, ln_gs1_bottom_offset,
                                                          lv_print_cc, lv_cc_mc_panel, lv_cc_justification,
                                                          ln_cc_side_offset, ln_cc_bottom_offset, ln_mc_max_length,
                                                          ln_mc_max_width, ln_mc_max_height, ln_mc_max_weight,
                                                          ln_mc_min_length, ln_mc_min_width, ln_mc_min_height,
                                                          ln_mc_min_weight
                                      FROM xxd_ont_customer_shipto_info_t st, xxd_ont_customer_header_info_t h
                                     WHERE     h.cust_account_id =
                                               c_pick_rec.cust_account_id
                                           AND st.cust_account_id(+) =
                                               h.cust_account_id
                                           --AND st.ship_to_site_id(+) = c_pick_rec.ship_cust_acct_site_id -- commented by KL
                                           AND st.cust_acct_site_id(+) =
                                               c_pick_rec.ship_cust_acct_site_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        lv_gs1_mc_panel        := NULL;
                                        lv_gs1_justification   := NULL;
                                        ln_gs1_side_offset     := NULL;
                                        ln_gs1_bottom_offset   := NULL;
                                        lv_print_cc            := NULL;
                                        lv_cc_mc_panel         := NULL;
                                        lv_cc_justification    := NULL;
                                        ln_cc_side_offset      := NULL;
                                        ln_cc_bottom_offset    := NULL;
                                        ln_mc_max_length       := NULL;
                                        ln_mc_max_width        := NULL;
                                        ln_mc_max_height       := NULL;
                                        ln_mc_max_weight       := NULL;
                                        ln_mc_min_length       := NULL;
                                        ln_mc_min_width        := NULL;
                                        ln_mc_min_height       := NULL;
                                        ln_mc_min_weight       := NULL;
                                END;

                                --Pack slip/Routing
                                BEGIN
                                    lv_print_pack_slip          := NULL;
                                    lv_service_time_frame       := NULL;
                                    lv_call_in_sla              := NULL;
                                    lv_tms_cutoff_time          := NULL;
                                    lv_routing_day1             := NULL;
                                    lv_scheduled_day1           := NULL;
                                    lv_routing_day2             := NULL;
                                    lv_scheduled_day2           := NULL;
                                    lv_back_to_back             := NULL;
                                    lv_tms_flag                 := NULL;
                                    lv_tms_url                  := NULL;
                                    lv_tms_username             := NULL;
                                    lv_tms_password             := NULL;
                                    lv_routing_contact_name     := NULL;
                                    lv_routing_contact_phone    := NULL;
                                    lv_routing_contact_fax      := NULL;
                                    lv_routing_contact_email    := NULL;
                                    lv_parcel_ship_method       := NULL;
                                    ln_parcel_weight_limit      := NULL;
                                    lv_parcel_dim_weight_flag   := NULL;
                                    ln_parcel_carton_limit      := NULL;
                                    lv_ltl_ship_method          := NULL;
                                    ln_ltl_weight_limit         := NULL;
                                    lv_ltl_dim_weight_flag      := NULL;
                                    ln_ltl_carton_limit         := NULL;
                                    lv_ftl_ship_method          := NULL;
                                    ln_ftl_weight_limit         := NULL;
                                    lv_ftl_dim_weight_flag      := NULL;
                                    ln_ftl_unit_limit           := NULL;
                                    lv_ftl_pallet_flag          := NULL;
                                    lv_routing_notes            := NULL;


                                    SELECT h.print_pack_slip, NVL (st.service_time_frame, h.service_time_frame), NVL (st.call_in_sla, h.call_in_sla),
                                           NVL (st.tms_cutoff_time, h.tms_cutoff_time), NVL (st.routing_day1, h.routing_day1), NVL (st.scheduled_day1, h.scheduled_day1),
                                           NVL (st.routing_day2, h.routing_day2), NVL (st.scheduled_day2, h.scheduled_day2), NVL (st.back_to_back, h.back_to_back),
                                           NVL (st.tms_flag, h.tms_flag), NVL (st.tms_url, h.tms_url), NVL (st.tms_username, h.tms_username),
                                           NVL (st.tms_password, h.tms_password), NVL (st.routing_contact_name, h.routing_contact_name), NVL (st.routing_contact_phone, h.routing_contact_phone),
                                           NVL (st.routing_contact_fax, h.routing_contact_fax), NVL (st.routing_contact_email, h.routing_contact_email), NVL (st.parcel_ship_method, h.parcel_ship_method),
                                           NVL (st.parcel_weight_limit, h.parcel_weight_limit), NVL (st.parcel_dim_weight_flag, h.parcel_dim_weight_flag), NVL (st.parcel_carton_limit, h.parcel_carton_limit),
                                           NVL (st.ltl_ship_method, h.ltl_ship_method), NVL (st.ltl_weight_limit, h.ltl_weight_limit), NVL (st.ltl_dim_weight_flag, h.ltl_dim_weight_flag),
                                           NVL (st.ltl_carton_limit, h.ltl_carton_limit), NVL (st.ftl_ship_method, h.ftl_ship_method), NVL (st.ftl_weight_limit, h.ftl_weight_limit),
                                           NVL (st.ftl_dim_weight_flag, h.ftl_dim_weight_flag), NVL (st.ftl_unit_limit, h.ftl_unit_limit), NVL (st.ftl_pallet_flag, h.ftl_pallet_flag),
                                           NVL (st.routing_notes, h.routing_notes)
                                      INTO lv_print_pack_slip, lv_service_time_frame, lv_call_in_sla, lv_tms_cutoff_time,
                                                             lv_routing_day1, lv_scheduled_day1, lv_routing_day2,
                                                             lv_scheduled_day2, lv_back_to_back, lv_tms_flag,
                                                             lv_tms_url, lv_tms_username, lv_tms_password,
                                                             lv_routing_contact_name, lv_routing_contact_phone, lv_routing_contact_fax,
                                                             lv_routing_contact_email, lv_parcel_ship_method, ln_parcel_weight_limit,
                                                             lv_parcel_dim_weight_flag, ln_parcel_carton_limit, lv_ltl_ship_method,
                                                             ln_ltl_weight_limit, lv_ltl_dim_weight_flag, ln_ltl_carton_limit,
                                                             lv_ftl_ship_method, ln_ftl_weight_limit, lv_ftl_dim_weight_flag,
                                                             ln_ftl_unit_limit, lv_ftl_pallet_flag, lv_routing_notes
                                      FROM xxd_ont_customer_shipto_info_t st, xxd_ont_customer_header_info_t h
                                     WHERE     h.cust_account_id =
                                               c_pick_rec.cust_account_id
                                           AND st.cust_account_id(+) =
                                               h.cust_account_id
                                           --AND st.ship_to_site_id(+) = c_pick_rec.ship_cust_acct_site_id --Commented by KL
                                           AND st.cust_acct_site_id(+) =
                                               c_pick_rec.ship_cust_acct_site_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        lv_print_pack_slip          := NULL;
                                        lv_service_time_frame       := NULL;
                                        lv_call_in_sla              := NULL;
                                        lv_tms_cutoff_time          := NULL;
                                        lv_routing_day1             := NULL;
                                        lv_scheduled_day1           := NULL;
                                        lv_routing_day2             := NULL;
                                        lv_scheduled_day2           := NULL;
                                        lv_back_to_back             := NULL;
                                        lv_tms_flag                 := NULL;
                                        lv_tms_url                  := NULL;
                                        lv_tms_username             := NULL;
                                        lv_tms_password             := NULL;
                                        lv_routing_contact_name     := NULL;
                                        lv_routing_contact_phone    := NULL;
                                        lv_routing_contact_fax      := NULL;
                                        lv_routing_contact_email    := NULL;
                                        lv_parcel_ship_method       := NULL;
                                        ln_parcel_weight_limit      := NULL;
                                        lv_parcel_dim_weight_flag   := NULL;
                                        ln_parcel_carton_limit      := NULL;
                                        lv_ltl_ship_method          := NULL;
                                        ln_ltl_weight_limit         := NULL;
                                        lv_ltl_dim_weight_flag      := NULL;
                                        ln_ltl_carton_limit         := NULL;
                                        lv_ftl_ship_method          := NULL;
                                        ln_ftl_weight_limit         := NULL;
                                        lv_ftl_dim_weight_flag      := NULL;
                                        ln_ftl_unit_limit           := NULL;
                                        lv_ftl_pallet_flag          := NULL;
                                        lv_routing_notes            := NULL;
                                END;

                                --Get VAS Code info
                                lv_gs1_format   := NULL;
                                lv_print_cc     := NULL;

                                --Add label parameters
                                BEGIN
                                    SELECT NVL (hzcasa.global_attribute16, hzca.attribute2), NVL (hzcasa.global_attribute17, hzca.attribute12)
                                      INTO lv_gs1_format, lv_print_cc
                                      FROM hz_cust_acct_sites_all hzcasa, hz_cust_accounts hzca, hz_party_sites hps
                                     WHERE     hzca.cust_account_id =
                                               c_pick_rec.cust_account_id
                                           AND hzca.party_id = hps.party_id
                                           AND hzcasa.cust_acct_site_id =
                                               c_pick_rec.ship_cust_acct_site_id
                                           AND hzcasa.party_site_id =
                                               hps.party_site_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        BEGIN
                                            SELECT hzca.attribute2, hzca.attribute12
                                              INTO lv_gs1_format, lv_print_cc
                                              FROM hz_cust_accounts hzca
                                             WHERE hzca.cust_account_id =
                                                   c_pick_rec.cust_account_id;
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                lv_gs1_format   := NULL;
                                                lv_print_cc     := NULL;
                                        END;
                                END;

                                msg ('lv_gs1_format: ' || lv_gs1_format);

                                IF lv_gs1_format IS NOT NULL
                                THEN
                                    INSERT INTO xxont_pick_intf_vas_hdr_stg (
                                                    warehouse_code,
                                                    order_number,
                                                    vas_code,
                                                    vas_description,
                                                    vas_item_number,
                                                    vas_label_type,
                                                    process_status,
                                                    request_id,
                                                    creation_date,
                                                    created_by,
                                                    last_update_date,
                                                    last_updated_by,
                                                    last_update_login,
                                                    source_type,
                                                    SOURCE,
                                                    destination,
                                                    record_id,
                                                    vas_free_text,
                                                    vas_label_format)
                                             VALUES (
                                                        SUBSTR (
                                                            c_pick_rec.warehouse_code,
                                                            1,
                                                            10),
                                                        SUBSTR (
                                                            c_pick_rec.order_number,
                                                            1,
                                                            30),
                                                        SUBSTR ('120', 1, 20),
                                                        SUBSTR (
                                                            'Label Printing',
                                                            1,
                                                            250), --TODO : Accurate description
                                                        NULL,
                                                        NULL,
                                                        gc_new_status,
                                                        g_num_request_id,
                                                        SYSDATE,
                                                        g_num_user_id,
                                                        SYSDATE,
                                                        g_num_user_id,
                                                        g_num_login_id,
                                                        'ORDER',
                                                        p_source,
                                                        p_dest,
                                                        xxdo_pick_intf_vas_hdr_seq.NEXTVAL,
                                                        NULL,
                                                        c_pick_rec.vas_label_format);
                                END IF;
                            END IF;

                            -- End of Change 3.0

                            BEGIN
                                ---Inserting into the pick interface header staging table
                                INSERT INTO xxont_pick_intf_hdr_stg (
                                                header_id,
                                                company,
                                                warehouse_code,
                                                order_number,
                                                order_type,
                                                brand_code,
                                                customer_code,
                                                customer_name,
                                                status,
                                                carrier,
                                                service_level,
                                                carrier_name,
                                                return_code,
                                                return_name,
                                                return_addr1,
                                                return_addr2,
                                                return_addr3,
                                                return_city,
                                                return_state,
                                                return_zip,
                                                return_country_code,
                                                return_phone,
                                                ship_to_code,
                                                ship_to_name,
                                                ship_to_addr1,
                                                ship_to_addr2,
                                                ship_to_addr3,
                                                ship_to_city,
                                                ship_to_state,
                                                ship_to_zip,
                                                ship_to_country_code,
                                                ship_to_phone,
                                                ship_to_residential_flag,
                                                ship_to_email,
                                                bill_to_code,
                                                bill_to_name,
                                                bill_to_addr1,
                                                bill_to_addr2,
                                                bill_to_addr3,
                                                bill_to_city,
                                                bill_to_state,
                                                bill_to_zip,
                                                bill_to_country_code,
                                                bill_to_phone,
                                                bill_to_email,
                                                store_number,
                                                store_name,
                                                dc_number,
                                                cust_po_number,
                                                department_code,
                                                department_name,
                                                order_date,
                                                earliest_ship_date,
                                                latest_ship_date,
                                                freight_terms,
                                                freight_account_number,
                                                --START Added as per ver 2.6
                                                bill_frght_to_name,
                                                bill_frght_to_addr1,
                                                bill_frght_to_addr2,
                                                bill_frght_to_addr3,
                                                bill_frght_to_city,
                                                bill_frght_to_state,
                                                bill_frght_to_zip,
                                                bill_frght_to_country_code,
                                                bill_frght_to_phone,
                                                --END Added as per ver 2.6
                                                vendor_number,
                                                priority,
                                                custom_cartonization_required,
                                                host_order_number,
                                                customer_language,
                                                process_status,
                                                request_id,
                                                creation_date,
                                                created_by,
                                                last_update_date,
                                                last_updated_by,
                                                last_update_login,
                                                source_type,
                                                SOURCE,
                                                destination,
                                                duty_terms,
                                                duty_account_number,
                                                charge_service_level,
                                                saturday_delivery_flag,
                                                ecomm_website_phone,
                                                ecomm_website_url,
                                                ecomm_newgistics_data,
                                                ecomm_usps_data,
                                                dropship_customer_name,
                                                dropship_contact_text,
                                                clearance_type,
                                                prepick_date,
                                                -- Start of Change 3.0
                                                customer_contact_phone,
                                                customer_email,
                                                customer_payment_method,
                                                customer_reward_number,
                                                total_merchandise_value,
                                                total_rewards_value,
                                                total_promo_value,
                                                total_shipping_charges,
                                                total_shipping_discount,
                                                total_tax,
                                                total_charge,
                                                total_savings,
                                                order_by_name,
                                                order_by_address1,
                                                order_by_address2,
                                                order_by_address3,
                                                order_by_city,
                                                order_by_state,
                                                order_by_country_code,
                                                order_by_zipcode, -- End of Change 3.0
                                                special_vas, --Start CCR0008657
                                                order_pack_type,
                                                customer_sales_channel,
                                                vas_label_format,
                                                gs1_mc_panel,
                                                gs1_justification,
                                                gs1_side_offset,
                                                gs1_bottom_offset,
                                                print_cc,
                                                cc_mc_panel,
                                                cc_justification,
                                                cc_side_offset,
                                                cc_bottom_offset,
                                                mc_max_length,
                                                mc_max_width,
                                                mc_max_height,
                                                mc_max_weight,
                                                mc_min_length,
                                                mc_min_width,
                                                mc_min_height,
                                                mc_min_weight,
                                                custom_dropship_packslip_flag,
                                                print_pack_slip,
                                                service_time_frame,
                                                call_in_sla,
                                                tms_cutoff_time,
                                                routing_day1,
                                                scheduled_day1,
                                                routing_day2,
                                                scheduled_day2,
                                                back_to_back,
                                                tms_flag,
                                                tms_url,
                                                tms_username,
                                                tms_password,
                                                routing_contact_name,
                                                routing_contact_phone,
                                                routing_contact_fax,
                                                routing_contact_email,
                                                parcel_ship_method,
                                                parcel_weight_limit,
                                                parcel_dim_weight_flag,
                                                parcel_carton_limit,
                                                ltl_ship_method,
                                                ltl_weight_limit,
                                                ltl_dim_weight_flag,
                                                ltl_carton_limit,
                                                ftl_ship_method,
                                                ftl_weight_limit,
                                                ftl_dim_weight_flag,
                                                ftl_unit_limit,
                                                ftl_pallet_flag,
                                                routing_notes --End CCR0008657
                                                             )
                                         VALUES (
                                                    l_num_stg_header_id,
                                                    SUBSTR (
                                                        c_pick_rec.company,
                                                        1,
                                                        50),
                                                    SUBSTR (
                                                        c_pick_rec.warehouse_code,
                                                        1,
                                                        10),
                                                    SUBSTR (
                                                        c_pick_rec.order_number,
                                                        1,
                                                        30),
                                                    SUBSTR (l_chr_order_type,
                                                            1,
                                                            50),
                                                    SUBSTR (
                                                        c_pick_rec.brand_code,
                                                        1,
                                                        100),
                                                    SUBSTR (
                                                        c_pick_rec.customer_code,
                                                        1,
                                                        30),
                                                    SUBSTR (
                                                        c_pick_rec.customer_name,
                                                        1,
                                                        50),
                                                    SUBSTR (
                                                        DECODE (l_num_count,
                                                                0, 'NEW',
                                                                'UPDATE'),
                                                        1,
                                                        10),
                                                    SUBSTR (
                                                        c_pick_rec.carrier,
                                                        1,
                                                        30),
                                                    --SUBSTR(c_pick_rec.service_level, 1, 30),  --Commented on 31MAY2018 for HPQC Defect # 1035 (Change 2.0)
                                                    SUBSTR (
                                                        c_pick_rec.service_level_code,
                                                        1,
                                                        30),
                                                    --Added on 31MAY2018 for HPQC Defect # 1035 (Change 2.0)
                                                    SUBSTR (
                                                        c_pick_rec.carrier_name,
                                                        1,
                                                        50),
                                                    SUBSTR (
                                                        c_pick_rec.return_code,
                                                        1,
                                                        50),
                                                    SUBSTR (
                                                        c_pick_rec.return_code,
                                                        1,
                                                        30),
                                                    SUBSTR (
                                                        c_pick_rec.return_address1,
                                                        1,
                                                        100),
                                                    SUBSTR (
                                                        c_pick_rec.return_address2,
                                                        1,
                                                        100),
                                                    SUBSTR (
                                                        c_pick_rec.return_address3,
                                                        1,
                                                        100),
                                                    SUBSTR (
                                                        c_pick_rec.return_city,
                                                        1,
                                                        50),
                                                    SUBSTR (
                                                        c_pick_rec.return_state,
                                                        1,
                                                        50),
                                                    SUBSTR (
                                                        c_pick_rec.return_postal_code,
                                                        1,
                                                        12),
                                                    SUBSTR (
                                                        c_pick_rec.return_country,
                                                        1,
                                                        5),
                                                    SUBSTR (
                                                        l_chr_return_phone,
                                                        1,
                                                        30),
                                                    SUBSTR (
                                                        c_pick_rec.ship_location,
                                                        1,
                                                        50),
                                                    SUBSTR (
                                                        c_pick_rec.ship_location,
                                                        1,
                                                        50),
                                                    SUBSTR (
                                                        c_pick_rec.ship_address1,
                                                        1,
                                                        100),
                                                    SUBSTR (
                                                        c_pick_rec.ship_address2,
                                                        1,
                                                        100),
                                                    SUBSTR (
                                                        c_pick_rec.ship_address3,
                                                        1,
                                                        100),
                                                    SUBSTR (
                                                        c_pick_rec.ship_city,
                                                        1,
                                                        50),
                                                    SUBSTR (
                                                        c_pick_rec.ship_state,
                                                        1,
                                                        50),
                                                    SUBSTR (
                                                        c_pick_rec.ship_postal_code,
                                                        1,
                                                        12),
                                                    SUBSTR (
                                                        c_pick_rec.ship_country,
                                                        1,
                                                        5),
                                                    SUBSTR (l_chr_ship_phone,
                                                            1,
                                                            30),
                                                    SUBSTR (
                                                        c_pick_rec.residential_flag,
                                                        1,
                                                        1),
                                                    SUBSTR (l_chr_ship_email,
                                                            1,
                                                            50),
                                                    SUBSTR (
                                                        c_pick_rec.bill_location,
                                                        1,
                                                        50),
                                                    SUBSTR (
                                                        c_pick_rec.bill_location,
                                                        1,
                                                        50),
                                                    SUBSTR (
                                                        c_pick_rec.bill_address1,
                                                        1,
                                                        100),
                                                    SUBSTR (
                                                        c_pick_rec.bill_address2,
                                                        1,
                                                        100),
                                                    SUBSTR (
                                                        c_pick_rec.bill_address3,
                                                        1,
                                                        100),
                                                    SUBSTR (
                                                        c_pick_rec.bill_city,
                                                        1,
                                                        50),
                                                    SUBSTR (
                                                        c_pick_rec.bill_state,
                                                        1,
                                                        50),
                                                    SUBSTR (
                                                        c_pick_rec.bill_postal_code,
                                                        1,
                                                        12),
                                                    SUBSTR (
                                                        c_pick_rec.bill_country,
                                                        1,
                                                        5),
                                                    SUBSTR (l_chr_bill_phone,
                                                            1,
                                                            30),
                                                    SUBSTR (l_chr_bill_email,
                                                            1,
                                                            50),
                                                    SUBSTR (
                                                        c_pick_rec.store_number,
                                                        1,
                                                        30),
                                                    SUBSTR (
                                                        c_pick_rec.store_name,
                                                        1,
                                                        100),
                                                    l_chr_dc_number, --SUBSTR (c_pick_rec.dc_number, 1, 30),--CCR0009572
                                                    SUBSTR (
                                                        c_pick_rec.ref_cust_po_number,
                                                        1,
                                                        30),
                                                    SUBSTR (
                                                        c_pick_rec.depart_number,
                                                        1,
                                                        20),
                                                    --SUBSTR(c_pick_rec.depart_name, 1, 50),   --Commented on 31MAY2018 for HPQC Defect # 1035 (Change 2.0)
                                                    SUBSTR (
                                                        NVL (
                                                            c_pick_rec.depart_name,
                                                            c_pick_rec.depart_number),
                                                        1,
                                                        50),
                                                    --Added on 31MAY2018 for HPQC Defect # 1035 (Change 2.0)
                                                    --Update VAS
                                                    c_pick_rec.order_date,
                                                    NVL (
                                                        ld_request_date,
                                                        c_pick_rec.earliest_ship_date),
                                                    NVL (
                                                        ld_cancel_date,
                                                        c_pick_rec.latest_ship_date),
                                                    /*  SUBSTR (
                                                         DECODE (c_pick_rec.freight_terms_code,
                                                                 'Paid', 'PREPAID',
                                                                 --'THIRD_PARTY', '3RDPARTY',    -- Commented as per change of ver 2.6
                                                                 'THIRD_PARTY', 'THIRDPARTY', -- Changes as per ver 2.6
                                                                 'COLLECT'),
                                                         1,
                                                         10),*/
                                                    --Begin CCR0008657
                                                    SUBSTR (
                                                        DECODE (
                                                            UPPER (
                                                                c_pick_rec.freight_terms_code),
                                                            'PAID', 'PREPAID',
                                                            'DUE', 'PREPAID',
                                                            'FREE', 'PREPAID',
                                                            'THIRD_PARTY', 'THIRDPARTY',
                                                            'COLLECT', 'COLLECT',
                                                            'PREPAID'),
                                                        1,
                                                        10),
                                                    --End CCR0008657
                                                    --Commented for change 2.3 (Uncommented for change 2.4)
                                                    --SUBSTR (lv_freight_terms_code, 1, 50), --Added for change 2.3 --Commented for change 2.4
                                                    SUBSTR (
                                                        c_pick_rec.freight_account,
                                                        1,
                                                        50),
                                                    --START Added as per ver 2.6
                                                    SUBSTR (
                                                        c_pick_rec.bill_location,
                                                        1,
                                                        50),
                                                    SUBSTR (
                                                        c_pick_rec.bill_address1,
                                                        1,
                                                        100),
                                                    SUBSTR (
                                                        c_pick_rec.bill_address2,
                                                        1,
                                                        100),
                                                    SUBSTR (
                                                        c_pick_rec.bill_address3,
                                                        1,
                                                        100),
                                                    SUBSTR (
                                                        c_pick_rec.bill_city,
                                                        1,
                                                        50),
                                                    SUBSTR (
                                                        c_pick_rec.bill_state,
                                                        1,
                                                        50),
                                                    SUBSTR (
                                                        c_pick_rec.bill_postal_code,
                                                        1,
                                                        12),
                                                    SUBSTR (
                                                        c_pick_rec.bill_country,
                                                        1,
                                                        5),
                                                    SUBSTR (l_chr_bill_phone,
                                                            1,
                                                            30),
                                                    --END Added as per ver 2.6
                                                    SUBSTR (
                                                        c_pick_rec.vendor_number,
                                                        1,
                                                        15),
                                                    SUBSTR (
                                                        c_pick_rec.shipment_priority_code,
                                                        1,
                                                        10),
                                                    '0',
                                                    c_pick_rec.ref_sales_order_number,
                                                    SUBSTR (
                                                        c_pick_rec.customer_language,
                                                        1,
                                                        30),
                                                    gc_new_status,    --'NEW',
                                                    g_num_request_id,
                                                    SYSDATE,
                                                    g_num_user_id,
                                                    SYSDATE,
                                                    g_num_user_id,
                                                    g_num_login_id,
                                                    'ORDER',
                                                    p_source,
                                                    p_dest,
                                                    SUBSTR (l_chr_duty_terms,
                                                            1,
                                                            10),
                                                    SUBSTR (
                                                        l_chr_duty_account_number,
                                                        1,
                                                        50),
                                                    SUBSTR (
                                                        l_chr_charge_service_level,
                                                        1,
                                                        30),
                                                    SUBSTR (
                                                        l_chr_saturday_delivery_flag,
                                                        1,
                                                        1),
                                                    SUBSTR (
                                                        l_chr_ecomm_phone,
                                                        1,
                                                        100),
                                                    SUBSTR (
                                                        l_chr_ecomm_website,
                                                        1,
                                                        300),
                                                    SUBSTR (
                                                        l_chr_newgistic_data,
                                                        1,
                                                        50),
                                                    SUBSTR (l_chr_usps_data,
                                                            1,
                                                            100),
                                                    --Begin CCR0008657
                                                    /*SUBSTR (l_chr_drop_cust_name, 1, 50), --Commented for change 2.3
                                                    SUBSTR (
                                                       NVL (l_chr_drop_cust_name,
                                                            l_chr_drop_ship_cust_name),
                                                       1,
                                                       50),               --Added for change 2.3
                                                    SUBSTR (l_chr_drop_cust_contact, 1, 2000),*/
                                                    SUBSTR (
                                                        lv_ds_customer_name,
                                                        1,
                                                        50),
                                                    lv_ds_contact_text,
                                                    --End CCR0008657
                                                    /*Ends DROP_SHIP*/
                                                    c_pick_rec.attribute_type,
                                                    ld_prepick_date,
                                                    -- Start of Change 3.0
                                                    SUBSTR (
                                                        lv_custom_ds_phone,
                                                        1,
                                                        150),
                                                    SUBSTR (
                                                        lv_custom_ds_email,
                                                        1,
                                                        150),
                                                    SUBSTR (
                                                        lv_cust_pay_method,
                                                        1,
                                                        240),
                                                    SUBSTR (
                                                        lv_cust_reward_num,
                                                        1,
                                                        240),
                                                    ln_total_merch_value,
                                                    ln_total_rewards_value,
                                                    ln_total_promo_value,
                                                    ln_total_ship_charges,
                                                    ln_total_ship_discount,
                                                    ln_total_tax,
                                                    ln_total_charges,
                                                    ln_total_savings,
                                                    SUBSTR (lv_order_by_name,
                                                            1,
                                                            240),
                                                    SUBSTR (
                                                        lv_order_by_address1,
                                                        1,
                                                        100),
                                                    SUBSTR (
                                                        lv_order_by_address2,
                                                        1,
                                                        100),
                                                    SUBSTR (
                                                        lv_order_by_address3,
                                                        1,
                                                        100),
                                                    SUBSTR (lv_order_by_city,
                                                            1,
                                                            50),
                                                    SUBSTR (
                                                        lv_order_by_state,
                                                        1,
                                                        50),
                                                    SUBSTR (
                                                        lv_order_by_country_code,
                                                        1,
                                                        12),
                                                    SUBSTR (
                                                        lv_order_by_zipcode,
                                                        1,
                                                        12), -- End of Change 3.0
                                                    c_pick_rec.special_vas, --Begin CCR0008657
                                                    c_pick_rec.order_pack_type,
                                                    lv_customer_sales_channel,
                                                    --c_pick_rec.vas_label_format, -- Commented by KL
                                                    lv_gs1_format,
                                                    lv_gs1_mc_panel,
                                                    lv_gs1_justification,
                                                    ln_gs1_side_offset,
                                                    ln_gs1_bottom_offset,
                                                    lv_print_cc,
                                                    lv_cc_mc_panel,
                                                    lv_cc_justification,
                                                    ln_cc_side_offset,
                                                    ln_cc_bottom_offset,
                                                    ln_mc_max_length,
                                                    ln_mc_max_width,
                                                    ln_mc_max_height,
                                                    ln_mc_max_weight,
                                                    ln_mc_min_length,
                                                    ln_mc_min_width,
                                                    ln_mc_min_height,
                                                    ln_mc_min_weight,
                                                    lv_custom_ds_packslip_flag,
                                                    lv_print_pack_slip,
                                                    lv_service_time_frame,
                                                    lv_call_in_sla,
                                                    lv_tms_cutoff_time,
                                                    lv_routing_day1,
                                                    lv_scheduled_day1,
                                                    lv_routing_day2,
                                                    lv_scheduled_day2,
                                                    lv_back_to_back,
                                                    lv_tms_flag,
                                                    lv_tms_url,
                                                    lv_tms_username,
                                                    lv_tms_password,
                                                    lv_routing_contact_name,
                                                    lv_routing_contact_phone,
                                                    lv_routing_contact_fax,
                                                    lv_routing_contact_email,
                                                    lv_parcel_ship_method,
                                                    ln_parcel_weight_limit,
                                                    lv_parcel_dim_weight_flag,
                                                    ln_parcel_carton_limit,
                                                    lv_ltl_ship_method,
                                                    ln_ltl_weight_limit,
                                                    lv_ltl_dim_weight_flag,
                                                    ln_ltl_carton_limit,
                                                    lv_ftl_ship_method,
                                                    ln_ftl_weight_limit,
                                                    lv_ftl_dim_weight_flag,
                                                    ln_ftl_unit_limit,
                                                    lv_ftl_pallet_flag,
                                                    lv_routing_notes --End CCR0008657
                                                                    );

                                ---Inserting into the pick interface status staging table
                                INSERT INTO xxdo_ont_pick_status_order (
                                                wh_id,
                                                order_number,
                                                tran_date,
                                                status,
                                                created_by,
                                                creation_date,
                                                last_updated_by,
                                                last_update_date,
                                                last_update_login,
                                                process_status,
                                                record_type,
                                                SOURCE,
                                                destination,
                                                request_id)
                                     VALUES (SUBSTR (c_pick_rec.warehouse_code, 1, 10), c_pick_rec.order_number, SYSDATE, gc_new_status, --'NEW',
                                                                                                                                         g_num_user_id, SYSDATE, g_num_user_id, SYSDATE, g_num_login_id, gc_processed_status, --'PROCESSED',
                                                                                                                                                                                                                              'INSERT', p_source
                                             , p_dest, g_num_request_id);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    p_retcode      := g_error;
                                    p_error_buf    :=
                                           'Error occured for Pick Ticket header insert '
                                        || SQLERRM;
                                    fnd_file.put_line (fnd_file.LOG,
                                                       p_error_buf);
                                    l_chr_commit   := 'N';
                            END;

                            l_num_comment_count            := 0;

                            IF c_pick_rec.shipping_instructions IS NOT NULL
                            THEN
                                msg (
                                    'Inserting header Shipping instructions');

                                BEGIN
                                    l_num_comment_count   :=
                                        l_num_comment_count + 10;

                                    BEGIN
                                        SELECT xxdo_pick_intf_hdr_cmt_seq.NEXTVAL
                                          INTO l_num_stg_hdr_cmt_id
                                          FROM DUAL;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                   'Error while getting next value from sequence XXDO_PICK_INTF_HDR_CMT_SEQ. Error is: '
                                                || SQLERRM);
                                            l_num_stg_hdr_cmt_id   := NULL;
                                    END;

                                    INSERT INTO xxont_pick_intf_cmt_hdr_stg (
                                                    header_id,
                                                    comment_id,
                                                    warehouse_code,
                                                    order_number,
                                                    comment_type,
                                                    comment_sequence,
                                                    comment_text,
                                                    process_status,
                                                    request_id,
                                                    creation_date,
                                                    created_by,
                                                    last_update_date,
                                                    last_updated_by,
                                                    last_update_login,
                                                    source_type,
                                                    SOURCE,
                                                    destination)
                                         VALUES (l_num_stg_header_id, l_num_stg_hdr_cmt_id, SUBSTR (c_pick_rec.warehouse_code, 1, 10), SUBSTR (c_pick_rec.order_number, 1, 30), 'SHIPPING', l_num_comment_count, SUBSTR (c_pick_rec.shipping_instructions, 1, 2000), gc_new_status, --'NEW',
                                                                                                                                                                                                                                                                                    g_num_request_id, SYSDATE, g_num_user_id, SYSDATE, g_num_user_id, g_num_login_id, 'ORDER'
                                                 , p_source, p_dest);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        p_retcode      := g_error;
                                        p_error_buf    :=
                                               'Error occured for Pick Ticket header Shipping instruction insert '
                                            || SQLERRM;
                                        fnd_file.put_line (fnd_file.LOG,
                                                           p_error_buf);
                                        l_chr_commit   := 'N';
                                END;
                            END IF;

                            IF c_pick_rec.packing_instructions IS NOT NULL
                            THEN
                                msg ('Inserting header Packing instructions');

                                BEGIN
                                    l_num_comment_count   :=
                                        l_num_comment_count + 10;

                                    BEGIN
                                        SELECT xxdo_pick_intf_hdr_cmt_seq.NEXTVAL
                                          INTO l_num_stg_hdr_cmt_id
                                          FROM DUAL;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                   'Error while getting next value from sequence XXDO_PICK_INTF_HDR_CMT_SEQ. Error is: '
                                                || SQLERRM);
                                            l_num_stg_hdr_cmt_id   := NULL;
                                    END;

                                    INSERT INTO xxont_pick_intf_cmt_hdr_stg (
                                                    header_id,
                                                    comment_id,
                                                    warehouse_code,
                                                    order_number,
                                                    comment_type,
                                                    comment_sequence,
                                                    comment_text,
                                                    process_status,
                                                    request_id,
                                                    creation_date,
                                                    created_by,
                                                    last_update_date,
                                                    last_updated_by,
                                                    last_update_login,
                                                    source_type,
                                                    SOURCE,
                                                    destination)
                                         VALUES (l_num_stg_header_id, l_num_stg_hdr_cmt_id, SUBSTR (c_pick_rec.warehouse_code, 1, 10), SUBSTR (c_pick_rec.order_number, 1, 30), 'PACKING', l_num_comment_count, SUBSTR (c_pick_rec.packing_instructions, 1, 2000), gc_new_status, --'NEW',
                                                                                                                                                                                                                                                                                  g_num_request_id, SYSDATE, g_num_user_id, SYSDATE, g_num_user_id, g_num_login_id, 'ORDER'
                                                 , p_source, p_dest);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        p_retcode      := g_error;
                                        p_error_buf    :=
                                               'Error occured for Pick Ticket header Packing instruction insert '
                                            || SQLERRM;
                                        fnd_file.put_line (fnd_file.LOG,
                                                           p_error_buf);
                                        l_chr_commit   := 'N';
                                END;
                            END IF;

                            IF c_pick_rec.comments1 IS NOT NULL
                            THEN
                                msg ('Inserting header Comments1');

                                BEGIN
                                    l_num_comment_count   :=
                                        l_num_comment_count + 10;

                                    BEGIN
                                        SELECT xxdo_pick_intf_hdr_cmt_seq.NEXTVAL
                                          INTO l_num_stg_hdr_cmt_id
                                          FROM DUAL;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                   'Error while getting next value from sequence XXDO_PICK_INTF_HDR_CMT_SEQ. Error is: '
                                                || SQLERRM);
                                            l_num_stg_hdr_cmt_id   := NULL;
                                    END;

                                    INSERT INTO xxont_pick_intf_cmt_hdr_stg (
                                                    header_id,
                                                    comment_id,
                                                    warehouse_code,
                                                    order_number,
                                                    comment_type,
                                                    comment_sequence,
                                                    comment_text,
                                                    process_status,
                                                    request_id,
                                                    creation_date,
                                                    created_by,
                                                    last_update_date,
                                                    last_updated_by,
                                                    last_update_login,
                                                    source_type,
                                                    SOURCE,
                                                    destination)
                                         VALUES (l_num_stg_header_id, l_num_stg_hdr_cmt_id, SUBSTR (c_pick_rec.warehouse_code, 1, 10), SUBSTR (c_pick_rec.order_number, 1, 30), 'COMMENTS1', l_num_comment_count, SUBSTR (c_pick_rec.comments1, 1, 2000), gc_new_status, --'NEW',
                                                                                                                                                                                                                                                                         g_num_request_id, SYSDATE, g_num_user_id, SYSDATE, g_num_user_id, g_num_login_id, 'ORDER'
                                                 , p_source, p_dest);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        p_retcode      := g_error;
                                        p_error_buf    :=
                                               'Error occured for Pick Ticket header Comments1 insert '
                                            || SQLERRM;
                                        fnd_file.put_line (fnd_file.LOG,
                                                           p_error_buf);
                                        l_chr_commit   := 'N';
                                END;
                            END IF;

                            IF c_pick_rec.comments2 IS NOT NULL
                            THEN
                                msg ('Inserting header Comments2');

                                BEGIN
                                    l_num_comment_count   :=
                                        l_num_comment_count + 10;

                                    BEGIN
                                        SELECT xxdo_pick_intf_hdr_cmt_seq.NEXTVAL
                                          INTO l_num_stg_hdr_cmt_id
                                          FROM DUAL;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                   'Error while getting next value from sequence XXDO_PICK_INTF_HDR_CMT_SEQ. Error is: '
                                                || SQLERRM);
                                            l_num_stg_hdr_cmt_id   := NULL;
                                    END;

                                    INSERT INTO xxont_pick_intf_cmt_hdr_stg (
                                                    header_id,
                                                    comment_id,
                                                    warehouse_code,
                                                    order_number,
                                                    comment_type,
                                                    comment_sequence,
                                                    comment_text,
                                                    process_status,
                                                    request_id,
                                                    creation_date,
                                                    created_by,
                                                    last_update_date,
                                                    last_updated_by,
                                                    last_update_login,
                                                    source_type,
                                                    SOURCE,
                                                    destination)
                                         VALUES (l_num_stg_header_id, l_num_stg_hdr_cmt_id, SUBSTR (c_pick_rec.warehouse_code, 1, 10), SUBSTR (c_pick_rec.order_number, 1, 30), 'COMMENTS2', l_num_comment_count, SUBSTR (c_pick_rec.comments2, 1, 2000), gc_new_status, --'NEW',
                                                                                                                                                                                                                                                                         g_num_request_id, SYSDATE, g_num_user_id, SYSDATE, g_num_user_id, g_num_login_id, 'ORDER'
                                                 , p_source, p_dest);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        p_retcode      := g_error;
                                        p_error_buf    :=
                                               'Error occured for Order header Comments2 insert '
                                            || SQLERRM;
                                        fnd_file.put_line (fnd_file.LOG,
                                                           p_error_buf);
                                        l_chr_commit   := 'N';
                                END;
                            END IF;

                            --Begin CCR0008657

                            lv_ticketing_instructions      := NULL;

                            BEGIN
                                SELECT REGEXP_REPLACE (REPLACE (REPLACE (REPLACE (UTL_RAW.CAST_TO_VARCHAR2 (DBMS_LOB.SUBSTR (fl.file_data, 2000, 1)), '>'), '<'), '&'), ' +', ' ') file_data
                                  INTO lv_ticketing_instructions
                                  FROM fnd_documents fd, fnd_lobs fl
                                 WHERE     1 = 1
                                       AND fl.file_id = fd.media_id
                                       AND fd.document_id =
                                           (SELECT MAX (document_id)
                                              FROM fnd_attached_docs_form_vl fad, fnd_document_categories_vl fdcv, oe_order_headers_all ooha
                                             WHERE     fad.category_id =
                                                       fdcv.category_id
                                                   AND fad.pk1_value =
                                                       TO_CHAR (
                                                           ooha.header_id)
                                                   AND fad.category_description =
                                                       'OM - Pick Ticket Instructions'
                                                   AND ooha.order_number =
                                                       c_pick_rec.ref_sales_order_number);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_ticketing_instructions   := NULL;
                            END;


                            IF lv_ticketing_instructions IS NOT NULL
                            THEN
                                msg (
                                    'Inserting header Ticketing Instructions');

                                BEGIN
                                    l_num_comment_count   :=
                                        l_num_comment_count + 10;

                                    BEGIN
                                        SELECT xxdo_pick_intf_hdr_cmt_seq.NEXTVAL
                                          INTO l_num_stg_hdr_cmt_id
                                          FROM DUAL;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                   'Error while getting next value from sequence XXDO_PICK_INTF_HDR_CMT_SEQ. Error is: '
                                                || SQLERRM);
                                            l_num_stg_hdr_cmt_id   := NULL;
                                    END;

                                    INSERT INTO xxont_pick_intf_cmt_hdr_stg (
                                                    header_id,
                                                    comment_id,
                                                    warehouse_code,
                                                    order_number,
                                                    comment_type,
                                                    comment_sequence,
                                                    comment_text,
                                                    process_status,
                                                    request_id,
                                                    creation_date,
                                                    created_by,
                                                    last_update_date,
                                                    last_updated_by,
                                                    last_update_login,
                                                    source_type,
                                                    SOURCE,
                                                    destination)
                                         VALUES (l_num_stg_header_id, l_num_stg_hdr_cmt_id, SUBSTR (c_pick_rec.warehouse_code, 1, 10), SUBSTR (c_pick_rec.order_number, 1, 30), 'TICKETING', l_num_comment_count, SUBSTR (lv_ticketing_instructions, 1, 2000), gc_new_status, --'NEW',
                                                                                                                                                                                                                                                                              g_num_request_id, SYSDATE, g_num_user_id, SYSDATE, g_num_user_id, g_num_login_id, 'ORDER'
                                                 , p_source, p_dest);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        p_retcode      := g_error;
                                        p_error_buf    :=
                                               'Error occured for Order header Ticketing insert '
                                            || SQLERRM;
                                        fnd_file.put_line (fnd_file.LOG,
                                                           p_error_buf);
                                        l_chr_commit   := 'N';
                                END;
                            END IF;

                            msg (
                                'Looping for Order: ' || c_pick_rec.order_number);

                            IF lb_is_special_vas
                            THEN
                                FOR vas_h_rec
                                    IN c_vas_hdr (
                                           c_pick_rec.customer_code,
                                           --c_pick_rec.ship_location,
                                           c_pick_rec.ship_cust_acct_site_id,
                                           c_pick_rec.org_id)
                                LOOP
                                    BEGIN
                                        INSERT INTO xxont_pick_intf_vas_hdr_stg (
                                                        warehouse_code,
                                                        order_number,
                                                        vas_code,
                                                        vas_description,
                                                        vas_item_number,
                                                        vas_label_type,
                                                        process_status,
                                                        request_id,
                                                        creation_date,
                                                        created_by,
                                                        last_update_date,
                                                        last_updated_by,
                                                        last_update_login,
                                                        source_type,
                                                        SOURCE,
                                                        destination,
                                                        record_id,
                                                        vas_free_text)
                                                 VALUES (
                                                            SUBSTR (
                                                                c_pick_rec.warehouse_code,
                                                                1,
                                                                10),
                                                            SUBSTR (
                                                                c_pick_rec.order_number,
                                                                1,
                                                                30),
                                                            SUBSTR (
                                                                vas_h_rec.vas_code,
                                                                1,
                                                                20),
                                                            SUBSTR (
                                                                vas_h_rec.description,
                                                                1,
                                                                250),
                                                            NULL,
                                                            NULL,
                                                            gc_new_status, --'NEW',
                                                            g_num_request_id,
                                                            SYSDATE,
                                                            g_num_user_id,
                                                            SYSDATE,
                                                            g_num_user_id,
                                                            g_num_login_id,
                                                            'ORDER',
                                                            p_source,
                                                            p_dest,
                                                            xxdo_pick_intf_vas_hdr_seq.NEXTVAL,
                                                            vas_h_rec.vas_comments);
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                   'Inside VAS hdr insert: '
                                                || p_error_buf);
                                    END;

                                    msg (
                                           'Looping for VAS Code: '
                                        || c_pick_rec.vas_code);

                                    FOR params_h_rec
                                        IN (SELECT parameter_name
                                              FROM XXDO.XXD_ONT_VAS_CODE_PARAMS_T
                                             WHERE     vas_code =
                                                       vas_h_rec.vas_code
                                                   AND org_id =
                                                       c_pick_rec.org_id)
                                    LOOP
                                        BEGIN
                                            msg (
                                                   'Looping for Parameter: '
                                                || params_h_rec.parameter_name);
                                            ln_param_value   := NULL;

                                            ln_param_value   :=
                                                get_vas_param_value (
                                                    c_pick_rec.order_header_id,
                                                    c_pick_rec.sold_to_org_id,
                                                    c_pick_rec.ship_to_org_id,
                                                    NULL,
                                                    params_h_rec.parameter_name);

                                            msg (
                                                   'Parameter Value: '
                                                || ln_param_value);

                                            INSERT INTO XXDO.XXD_ONT_PK_INTF_P_HDR_STG_T (
                                                            WAREHOUSE_CODE,
                                                            ORDER_NUMBER,
                                                            VAS_CODE,
                                                            PARAMETER,
                                                            PARAMETER_VALUE,
                                                            PROCESS_STATUS,
                                                            ERROR_MESSAGE,
                                                            REQUEST_ID,
                                                            CREATION_DATE,
                                                            CREATED_BY,
                                                            LAST_UPDATE_DATE,
                                                            LAST_UPDATED_BY,
                                                            LAST_UPDATE_LOGIN,
                                                            SOURCE,
                                                            DESTINATION)
                                                     VALUES (
                                                                SUBSTR (
                                                                    c_pick_rec.warehouse_code,
                                                                    1,
                                                                    10),
                                                                SUBSTR (
                                                                    c_pick_rec.order_number,
                                                                    1,
                                                                    30),
                                                                SUBSTR (
                                                                    vas_h_rec.vas_code,
                                                                    1,
                                                                    20),
                                                                params_h_rec.parameter_name,
                                                                ln_param_value,
                                                                gc_new_status, --'NEW',
                                                                NULL,
                                                                g_num_request_id,
                                                                SYSDATE,
                                                                g_num_user_id,
                                                                SYSDATE,
                                                                g_num_user_id,
                                                                g_num_login_id,
                                                                p_source,
                                                                p_dest);
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                fnd_file.put_line (
                                                    fnd_file.LOG,
                                                       'Exception while inserting VAS parameters'
                                                    || p_error_buf);
                                        END;
                                    END LOOP;
                                END LOOP;
                            END IF;
                        -- Modified for CCR0007638, added verify_vas_code
                        /* IF c_pick_rec.vas_code IS NOT NULL
                         THEN
                            l_vas_code_tbl.DELETE;
                            process_vas_code (c_pick_rec.vas_code,
                                              l_vas_code_tbl);
                         --verify_vas_code (c_pick_rec.customer_code,
                         --                 l_vas_code_tbl);
                         ELSE
                            l_vas_code_tbl.DELETE;
                        --*verify_vas_code (c_pick_rec.customer_code,
                         --                 l_vas_code_tbl);
                         END IF;

                         IF l_vas_code_tbl.COUNT > 0
                         THEN
                            FOR i IN l_vas_code_tbl.FIRST .. l_vas_code_tbl.LAST
                            LOOP
                               BEGIN
                                  INSERT INTO xxont_pick_intf_vas_hdr_stg (
                                                 warehouse_code,
                                                 order_number,
                                                 vas_code,
                                                 vas_description,
                                                 vas_item_number,
                                                 vas_label_type,
                                                 process_status,
                                                 request_id,
                                                 creation_date,
                                                 created_by,
                                                 last_update_date,
                                                 last_updated_by,
                                                 last_update_login,
                                                 source_type,
                                                 SOURCE,
                                                 destination,
                                                 record_id)
                                     SELECT SUBSTR (c_pick_rec.warehouse_code,
                                                    1,
                                                    10),
                                            SUBSTR (c_pick_rec.order_number,
                                                    1,
                                                    30),
                                            SUBSTR (fdvl.title, 1, 20),
                                            SUBSTR (fattach.short_text, 1, 250),
                                            NULL,
                                            NULL,
                                            gc_new_status,                --'NEW',
                                            g_num_request_id,
                                            SYSDATE,
                                            g_num_user_id,
                                            SYSDATE,
                                            g_num_user_id,
                                            g_num_login_id,
                                            'ORDER',
                                            p_source,
                                            p_dest,
                                            xxdo_pick_intf_vas_hdr_seq.NEXTVAL
                                       FROM fnd_documents_vl fdvl,
                                            fnd_documents_short_text fattach
                                      WHERE     1 = 1
                                            AND fdvl.media_id = fattach.media_id
                                            AND fdvl.category_description =
                                                   'VAS Codes'
                                            AND fdvl.title =
                                                   l_vas_code_tbl (i).vas_code;
                               EXCEPTION
                                  WHEN OTHERS
                                  THEN
                                     p_retcode := g_error;
                                     p_error_buf :=
                                           'Error occured for VAS Code headers insert '
                                        || SQLERRM;
                                     fnd_file.put_line (fnd_file.LOG,
                                                        p_error_buf);
                                     l_chr_commit := 'N';
                               END;
                            END LOOP;
                         END IF;*/
                        /* commented per CCR0008657
                                             --Added for CCR0007638, Customer and SKU style VAS Codes - START
                                             BEGIN
                                                SELECT xxdo_pick_intf_vas_hdr_seq.NEXTVAL
                                                  INTO l_num_stg_hdr_vas_id
                                                  FROM DUAL;

                                                INSERT INTO xxont_pick_intf_vas_hdr_stg (
                                                               warehouse_code,
                                                               order_number,
                                                               vas_code,
                                                               vas_description,
                                                               vas_item_number,
                                                               vas_label_type,
                                                               process_status,
                                                               request_id,
                                                               creation_date,
                                                               created_by,
                                                               last_update_date,
                                                               last_updated_by,
                                                               last_update_login,
                                                               source_type,
                                                               SOURCE,
                                                               destination,
                                                               record_id)
                                                   SELECT DISTINCT
                                                          SUBSTR (c_pick_rec.warehouse_code, 1, 10),
                                                          SUBSTR (c_pick_rec.order_number, 1, 30),
                                                          flv.tag,
                                                          flv.description,
                                                          NULL,
                                                          NULL,
                                                          'NEW',
                                                          g_num_request_id,
                                                          SYSDATE,
                                                          g_num_user_id,
                                                          SYSDATE,
                                                          g_num_user_id,
                                                          g_num_login_id,
                                                          'ORDER',
                                                          p_source,
                                                          p_dest,
                                                          l_num_stg_hdr_vas_id
                                                     FROM apps.wsh_new_deliveries wnd,
                                                          apps.wsh_delivery_assignments wda,
                                                          apps.wsh_delivery_details wdd,
                                                          apps.xxd_common_items_v xdiv,
                                                          apps.fnd_lookup_values flv,
                                                          apps.xxd_ra_customers_v cust
                                                    WHERE     wnd.delivery_id =
                                                                 c_pick_rec.order_number
                                                          AND wnd.organization_id =
                                                                 c_pick_rec.organization_id
                                                          AND wnd.delivery_id = wda.delivery_id
                                                          AND wda.delivery_detail_id =
                                                                 wdd.delivery_detail_id
                                                          AND wdd.source_code = 'OE'
                                                          AND wdd.inventory_item_id =
                                                                 xdiv.inventory_item_id
                                                          AND wdd.organization_id =
                                                                 xdiv.organization_id
                                                          AND wnd.customer_id = cust.customer_id
                                                          AND flv.lookup_type =
                                                                 'XXDO_CUSTOMER_STYLE_VAS_CODE'
                                                          AND flv.LANGUAGE = 'US'
                                                          AND flv.enabled_flag = 'Y'
                                                          AND SYSDATE BETWEEN NVL (
                                                                                 flv.start_date_active,
                                                                                 SYSDATE - 1)
                                                                          AND NVL (
                                                                                 flv.end_date_active,
                                                                                 SYSDATE + 1)
                                                          AND cust.customer_number =
                                                                 TRIM (
                                                                    REGEXP_SUBSTR (lookup_code,
                                                                                   '[^,]+'))
                                                          AND xdiv.style_number =
                                                                 TRIM (REGEXP_SUBSTR (lookup_code,
                                                                                      '[^,]+',
                                                                                      1,
                                                                                      2));
                                             EXCEPTION
                                                WHEN OTHERS
                                                THEN
                                                   p_retcode := 2;
                                                   p_error_buf :=
                                                         'Error occured for VAS Code headers insert for Customer and SKU style'
                                                      || SQLERRM;
                                                   fnd_file.put_line (fnd_file.LOG, p_error_buf);
                                                   l_chr_commit := 'N';
                                             END;
                                          -- Added for CCR0007638, Customer and SKU style VAS Codes  -- END
                                          */


                        /* Label related VAS */
                        /* Commented perCCR0008657
                      BEGIN
                          INSERT INTO xxont_pick_intf_vas_hdr_stg (
                                          warehouse_code,
                                          order_number,
                                          vas_code,
                                          vas_description,
                                          vas_item_number,
                                          vas_label_type,
                                          process_status,
                                          request_id,
                                          creation_date,
                                          created_by,
                                          last_update_date,
                                          last_updated_by,
                                          last_update_login,
                                          source_type,
                                          SOURCE,
                                          destination,
                                          record_id,
                                          vas_label_format,
                                          vas_label_justification,
                                          vas_label_offset)
                              --START Commented as per ver 2.6
                              /*
                             SELECT SUBSTR (c_pick_rec.warehouse_code, 1, 10),
                                    SUBSTR (c_pick_rec.order_number, 1, 30),
                                    '120', 'Label Printing', NULL, NULL,
                                    gc_new_status,                     --'NEW',
                                                  g_num_request_id, SYSDATE,
                                    g_num_user_id, SYSDATE, g_num_user_id,
                                    g_num_login_id, 'ORDER', p_source, p_dest,
                                    xxdo_pick_intf_vas_hdr_seq.NEXTVAL,
                                    SUBSTR (c_pick_rec.vas_label_format, 1,
                                            250),
                                    SUBSTR (dl.attribute1, 1, 1),
                                    ROUND (dl.attribute2, 2)
                               FROM do_custom.do_lookups dl
                              WHERE 1 = 1
                                AND dl.lookup_type = 'DO_WCS_UCC_LABEL_POS'
                                AND dl.ID = c_pick_rec.cust_account_id
                                AND c_pick_rec.order_source_id <> 1044;

                              --END Commented as per ver 2.6
                              --START Added as per ver 2.6


                              SELECT SUBSTR (c_pick_rec.warehouse_code,
                                             1,
                                             10),
                                     SUBSTR (c_pick_rec.order_number,
                                             1,
                                             30),
                                     '120',
                                     'Label Printing',
                                     NULL,
                                     NULL,
                                     gc_new_status,
                                     g_num_request_id,
                                     SYSDATE,
                                     g_num_user_id,
                                     SYSDATE,
                                     g_num_user_id,
                                     g_num_login_id,
                                     'ORDER',
                                     p_source,
                                     p_dest,
                                     xxdo_pick_intf_vas_hdr_seq.NEXTVAL,
                                     SUBSTR (
                                         c_pick_rec.vas_label_format,
                                         1,
                                         250),
                                     SUBSTR (flv.attribute1, 1, 1),
                                     ROUND (flv.attribute2, 2)
                                FROM fnd_lookup_values flv
                               WHERE     1 = 1
                                     AND flv.language =
                                         USERENV ('LANG')
                                     AND flv.enabled_flag = 'Y'
                                     AND SYSDATE BETWEEN NVL (
                                                             TRUNC (
                                                                 flv.start_date_active),
                                                             SYSDATE)
                                                     AND NVL (
                                                             TRUNC (
                                                                 flv.end_date_active),
                                                               SYSDATE
                                                             + 1)
                                     AND flv.lookup_type =
                                         'XXDO_WCS_UCC_LABEL_POS'
                                     AND TO_NUMBER (flv.lookup_code) =
                                         c_pick_rec.cust_account_id
                                     AND c_pick_rec.order_source_id <>
                                         1044;
                              --END Added as per ver 2.6
                      EXCEPTION
                          WHEN OTHERS
                          THEN
                              p_retcode := g_error;
                              p_error_buf :=
                                     'Error occured for VAS Code headers insert '
                                  || SQLERRM;
                              fnd_file.put_line (fnd_file.LOG,
                                                 p_error_buf);
                              l_chr_commit := 'N';
                      END;
                  /* end of header processing */
                        END IF;

                        msg ('Processing lines for Order');
                        msg ('Inserting line record');

                        BEGIN
                            l_chr_customer_item   := NULL;

                            SELECT mci.customer_item_number
                              INTO l_chr_customer_item
                              FROM mtl_customer_items mci, mtl_customer_item_xrefs mcix
                             WHERE     1 = 1
                                   AND mci.customer_item_id =
                                       mcix.customer_item_id
                                   AND mcix.inventory_item_id =
                                       c_pick_rec.inventory_item_id
                                   AND mci.customer_id =
                                       c_pick_rec.cust_account_id
                                   AND mci.inactive_flag = 'N'
                                   AND mcix.inactive_flag = 'N'
                                   AND ROWNUM = 1;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_chr_customer_item   := NULL;
                        END;

                        BEGIN
                            l_chr_hts_code   := NULL;

                            SELECT mcb.segment1 hts_code
                              INTO l_chr_hts_code
                              FROM apps.mtl_categories_b mcb, apps.mtl_item_categories mic2, apps.mtl_category_sets mcs
                             WHERE     1 = 1
                                   AND mic2.category_set_id =
                                       mcs.category_set_id
                                   AND mic2.category_id = mcb.category_id
                                   AND mic2.organization_id =
                                       c_pick_rec.organization_id
                                   AND mic2.inventory_item_id =
                                       c_pick_rec.inventory_item_id
                                   AND mcb.structure_id = mcs.structure_id
                                   AND mcs.category_set_name = 'TARRIF CODE';
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                BEGIN
                                    SELECT tag
                                      INTO l_chr_hts_code
                                      FROM apps.fnd_lookup_values
                                     WHERE     1 = 1
                                           AND lookup_type =
                                               'XXDO_DC2_HTS_CODE'
                                           AND LANGUAGE = 'US'
                                           AND lookup_code =
                                               c_pick_rec.item_style;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        l_chr_hts_code   := NULL;
                                END;
                            WHEN OTHERS
                            THEN
                                l_chr_hts_code   := NULL;
                        END;

                        BEGIN
                            BEGIN
                                SELECT xxdo_pick_intf_line_seq.NEXTVAL
                                  INTO l_num_stg_line_id
                                  FROM DUAL;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Error while getting next value from sequence XXDO_PICK_INTF_LINE_SEQ. Error is: '
                                        || SQLERRM);
                                    l_num_stg_line_id   := NULL;
                            END;

                            l_num_freight_amount      := 0;

                            BEGIN
                                SELECT NVL (ROUND (SUM (adjusted_amount_per_pqty), 2), 0)
                                  INTO l_num_freight_amount
                                  FROM oe_price_adjustments opa
                                 WHERE     1 = 1
                                       AND opa.list_line_type_code =
                                           'FREIGHT_CHARGE'
                                       AND opa.line_id = c_pick_rec.line_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_num_freight_amount   := 0;
                            END;

                            -- Start of Change 3.0
                            --Already using lookup fetched the count into lv_custom_data_flag, using this flag and then fetching the line values

                            ln_cust_item_price        := NULL;
                            ln_split_from_line_id     := NULL;
                            ln_ord_line_number        := NULL;
                            lv_customer_gender_code   := NULL;
                            lv_customer_department    := NULL;
                            lv_customer_major_class   := NULL;
                            lv_customer_sub_class     := NULL;
                            lv_customer_box_id        := NULL;

                            --IF NVL (lv_custom_data_flag, 'N') = 'Y'
                            IF (NVL (lv_custom_ds_packslip_flag, 'N') = 'Y' OR lb_is_special_vas)
                            THEN
                                BEGIN
                                    SELECT --cust_ord_line.customer_item_price, commneted 4.2 CCR0009359
                                           cust_ord_line.customer_gender_code, cust_ord_line.customer_department, cust_ord_line.customer_major_class,
                                           cust_ord_line.customer_sub_class, cust_ord_line.customer_box_id
                                      INTO --ln_cust_item_price, commneted 4.2 CCR0009359
                                           lv_customer_gender_code, lv_customer_department, lv_customer_major_class, lv_customer_sub_class,
                                                                  lv_customer_box_id
                                      FROM xxdo.xxd_ont_cust_ord_line_dtls_t cust_ord_line, apps.wsh_new_deliveries wnd, apps.wsh_delivery_assignments wda,
                                           apps.wsh_delivery_details wdd, apps.oe_order_lines_all ool
                                     WHERE     1 = 1
                                           AND wnd.delivery_id =
                                               c_pick_rec.header_id
                                           AND wnd.delivery_id =
                                               wda.delivery_id
                                           AND wda.delivery_detail_id =
                                               wdd.delivery_detail_id
                                           AND wdd.source_code = 'OE' --Added for change 2.0
                                           AND wdd.organization_id =
                                               wnd.organization_id
                                           AND wdd.source_line_id =
                                               ool.line_id
                                           AND wdd.source_header_id =
                                               ool.header_id
                                           AND ool.line_id =
                                               c_pick_rec.line_id -- Added for Change 3.0
                                           AND wdd.organization_id =
                                               ool.ship_from_org_id
                                           AND ool.orig_sys_document_ref =
                                               cust_ord_line.orig_sys_document_ref
                                           AND ool.orig_sys_line_ref =
                                               cust_ord_line.orig_sys_line_ref;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        --ln_cust_item_price := NULL; commneted 4.2 CCR0009359
                                        lv_customer_gender_code   := NULL;
                                        lv_customer_department    := NULL;
                                        lv_customer_major_class   := NULL;
                                        lv_customer_sub_class     := NULL;
                                        lv_customer_box_id        := NULL;

                                        -- Handling the case with Split Shipments scenario

                                        BEGIN
                                            ln_split_from_line_id   := NULL;
                                            ln_ord_line_number      := NULL;

                                            SELECT split_from_line_id, line_number
                                              INTO ln_split_from_line_id, ln_ord_line_number
                                              FROM oe_order_lines_all oola
                                             WHERE     oola.line_id =
                                                       c_pick_rec.line_id
                                                   AND oola.header_id =
                                                       c_pick_rec.order_header_id;

                                            --AND split_from_line_id IS NOT NULL;

                                            IF ln_split_from_line_id
                                                   IS NOT NULL
                                            THEN
                                                --ln_cust_item_price := NULL;

                                                BEGIN
                                                    SELECT --cust_ord_line.customer_item_price, commneted 4.2 CCR0009359
                                                           cust_ord_line.customer_gender_code, cust_ord_line.customer_department, cust_ord_line.customer_major_class,
                                                           cust_ord_line.customer_sub_class, cust_ord_line.customer_box_id
                                                      INTO --ln_cust_item_price, commneted 4.2 CCR0009359
                                                           lv_customer_gender_code, lv_customer_department, lv_customer_major_class,
                                                           lv_customer_sub_class, lv_customer_box_id
                                                      FROM xxdo.xxd_ont_cust_ord_line_dtls_t cust_ord_line, apps.wsh_new_deliveries wnd, apps.wsh_delivery_assignments wda,
                                                           apps.wsh_delivery_details wdd, apps.oe_order_lines_all ool
                                                     WHERE     1 = 1
                                                           AND wnd.delivery_id =
                                                               c_pick_rec.header_id
                                                           AND wnd.delivery_id =
                                                               wda.delivery_id
                                                           AND wda.delivery_detail_id =
                                                               wdd.delivery_detail_id
                                                           AND wdd.source_code =
                                                               'OE' --Added for change 2.0
                                                           AND wdd.organization_id =
                                                               wnd.organization_id
                                                           AND wdd.source_line_id =
                                                               ool.line_id
                                                           AND wdd.source_header_id =
                                                               ool.header_id
                                                           AND wdd.organization_id =
                                                               ool.ship_from_org_id
                                                           AND ool.orig_sys_document_ref =
                                                               cust_ord_line.orig_sys_document_ref
                                                           AND ool.orig_sys_line_ref =
                                                               cust_ord_line.orig_sys_line_ref
                                                           AND ool.line_number =
                                                               ln_ord_line_number
                                                           AND ool.shipment_number =
                                                               1;
                                                EXCEPTION
                                                    WHEN OTHERS
                                                    THEN
                                                        --ln_cust_item_price := NULL; commneted 4.2 CCR0009359
                                                        lv_customer_gender_code   :=
                                                            NULL;
                                                        lv_customer_department   :=
                                                            NULL;
                                                        lv_customer_major_class   :=
                                                            NULL;
                                                        lv_customer_sub_class   :=
                                                            NULL;
                                                        lv_customer_box_id   :=
                                                            NULL;
                                                END;
                                            END IF;
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                ln_split_from_line_id   :=
                                                    NULL;
                                                ln_ord_line_number   := NULL;
                                                --ln_cust_item_price := NULL; commneted 4.2 CCR0009359
                                                lv_customer_gender_code   :=
                                                    NULL;
                                                lv_customer_department   :=
                                                    NULL;
                                                lv_customer_major_class   :=
                                                    NULL;
                                                lv_customer_sub_class   :=
                                                    NULL;
                                                lv_customer_box_id   :=
                                                    NULL;
                                        END;
                                END;
                            END IF;

                            --Begin CCR0008657
                            IF lb_is_special_vas
                            THEN                     --VAS Automation musicals
                                IF c_pick_rec.musical_details IS NOT NULL
                                THEN
                                    /*lv_assortment_id :=
                                        TRIM (
                                            SUBSTR (
                                                c_pick_rec.musical_details,
                                                1,
                                                  INSTR (
                                                      c_pick_rec.musical_details,
                                                      '.',
                                                      1,
                                                      1)
                                                - 1));


                                    lv_assortment_qty :=
                                        TRIM (
                                            SUBSTR (
                                                c_pick_rec.musical_details,
                                                  INSTR (
                                                      c_pick_rec.musical_details,
                                                      '.',
                                                      1,
                                                      1)
                                                + 1));*/
                                    lv_assortment_id   :=
                                        xxd_wms_hj_int_pkg.parse_attributes (
                                            c_pick_rec.musical_details,
                                            'vendor_sku');
                                    lv_assortment_qty   :=
                                        xxd_wms_hj_int_pkg.parse_attributes (
                                            c_pick_rec.musical_details,
                                            'casepack_qty');
                                END IF;
                            END IF;

                            --End CCR0008657

                            -- End of Change 3.0
                            ln_cust_item_price        :=
                                c_pick_rec.customer_item_price; -- Added 4.2 CCR0009359

                            INSERT INTO xxont_pick_intf_line_stg (
                                            header_id,
                                            line_id,
                                            warehouse_code,
                                            order_number,
                                            line_number,
                                            item_number,
                                            qty,
                                            order_uom,
                                            reason_code,
                                            reason_description,
                                            sales_order_number,
                                            cust_po_number,
                                            latest_ship_date,
                                            unit_msrp_price,
                                            unit_list_price,
                                            unit_selling_price,
                                            tax_amount_per_unit,
                                            scheduled_ship_date,
                                            earliest_ship_date,
                                            harmonized_tariff_code,
                                            carton_crossdock_ref,
                                            process_status,
                                            request_id,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_updated_by,
                                            last_update_login,
                                            source_type,
                                            SOURCE,
                                            destination,
                                            freight_amount_per_unit,
                                            customer_color_name,
                                            customer_item_number,
                                            customer_size_name,
                                            customer_style_name,
                                            attribute10,
                                            attribute11,
                                            attribute12,
                                            attribute1 ---Added for change 2.0 --It holds order type
                                                      ,
                                            customer_item_price -- Added for Change 3.0
                                                               ,
                                            customer_style_number, -- Added for Change 3.0
                                            assortment_id,
                                            assortment_qty,
                                            customer_gender_code,
                                            customer_department,
                                            customer_major_class,
                                            customer_sub_class,
                                            customer_box_id)
                                 VALUES (l_num_stg_header_id, l_num_stg_line_id, SUBSTR (c_pick_rec.warehouse_code, 1, 10), SUBSTR (c_pick_rec.order_number, 1, 30), c_pick_rec.line_id, SUBSTR (c_pick_rec.item_number, 1, 400), SUBSTR (c_pick_rec.qty, 1, 30), SUBSTR (c_pick_rec.order_uom, 1, 50), SUBSTR (c_pick_rec.reason_code, 1, 50), SUBSTR (c_pick_rec.reason_description, 1, 250), SUBSTR (c_pick_rec.ref_sales_order_number, 1, 20), SUBSTR (c_pick_rec.ref_cust_po_number, 1, 30), c_pick_rec.latest_ship_date, ROUND (c_pick_rec.unit_list_price, 2), ROUND (c_pick_rec.unit_list_price, 2), ROUND (c_pick_rec.unit_selling_price, 2), ROUND (c_pick_rec.unit_tax_amount, 2), c_pick_rec.schedule_ship_date, c_pick_rec.earliest_ship_date, SUBSTR (l_chr_hts_code, 1, 30), SUBSTR (c_pick_rec.crossdock_ref, 1, 30), gc_new_status, --'NEW',
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     g_num_request_id, SYSDATE, g_num_user_id, SYSDATE, g_num_user_id, g_num_login_id, 'ORDER', p_source, p_dest, SUBSTR (l_num_freight_amount, 1, 30), SUBSTR (c_pick_rec.customer_color_name, 1, 30), SUBSTR (NVL (c_pick_rec.customer_item_number, l_chr_customer_item), 1, 50), SUBSTR (c_pick_rec.customer_size_name, 1, 30), SUBSTR (c_pick_rec.customer_style_name, 1, 50), SUBSTR (c_pick_rec.customer_dim_name, 1, 50), SUBSTR (c_pick_rec.customer_free_desc1, 1, 50), SUBSTR (c_pick_rec.customer_free_desc2, 1, 50), SUBSTR (l_chr_order_type, 1, 50) --Added for change 2.0 (Order Type)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 , ln_cust_item_price -- Added for Change 3.0
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     , SUBSTR (c_pick_rec.customer_style_number, 1, 150), -- Added for Change 3.0
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          lv_assortment_id, lv_assortment_qty, lv_customer_gender_code, lv_customer_department, lv_customer_major_class, lv_customer_sub_class
                                         , lv_customer_box_id);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                p_retcode      := g_error;
                                p_error_buf    :=
                                       'Error occured for Order line insert '
                                    || SQLERRM;
                                fnd_file.put_line (fnd_file.LOG, p_error_buf);
                                l_chr_commit   := 'N';
                        END;

                        l_num_comment_count   := 0;

                        IF c_pick_rec.line_shipping_instructions IS NOT NULL
                        THEN
                            msg ('Inserting line shipping instructions');

                            BEGIN
                                l_num_comment_count   :=
                                    l_num_comment_count + 10;

                                BEGIN
                                    SELECT xxdo_pick_intf_line_cmt_seq.NEXTVAL
                                      INTO l_num_stg_line_cmt_id
                                      FROM DUAL;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'Error while getting next value from sequence XXDO_PICK_INTF_LINE_CMT_SEQ. Error is: '
                                            || SQLERRM);
                                        l_num_stg_line_cmt_id   := NULL;
                                END;

                                INSERT INTO xxont_pick_intf_cmt_line_stg (
                                                line_id,
                                                comment_id,
                                                warehouse_code,
                                                order_number,
                                                line_number,
                                                comment_type,
                                                comment_sequence,
                                                comment_text,
                                                process_status,
                                                request_id,
                                                creation_date,
                                                created_by,
                                                last_update_date,
                                                last_updated_by,
                                                last_update_login,
                                                source_type,
                                                SOURCE,
                                                destination)
                                     VALUES (l_num_stg_line_id, l_num_stg_line_cmt_id, SUBSTR (c_pick_rec.warehouse_code, 1, 10), SUBSTR (c_pick_rec.order_number, 1, 30), c_pick_rec.line_id, 'SHIPPING', l_num_comment_count, SUBSTR (c_pick_rec.line_shipping_instructions, 1, 4000), gc_new_status, --'NEW',
                                                                                                                                                                                                                                                                                                        g_num_request_id, SYSDATE, g_num_user_id, SYSDATE, g_num_user_id, g_num_login_id
                                             , 'ORDER', p_source, p_dest);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    p_retcode      := g_error;
                                    p_error_buf    :=
                                           'Error occured for Order line shipping instruction insert '
                                        || SQLERRM;
                                    fnd_file.put_line (fnd_file.LOG,
                                                       p_error_buf);
                                    l_chr_commit   := 'N';
                            END;
                        END IF;

                        IF c_pick_rec.line_packing_instructions IS NOT NULL
                        THEN
                            msg ('Inserting line packing instructions');

                            BEGIN
                                l_num_comment_count   :=
                                    l_num_comment_count + 10;

                                BEGIN
                                    SELECT xxdo_pick_intf_line_cmt_seq.NEXTVAL
                                      INTO l_num_stg_line_cmt_id
                                      FROM DUAL;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'Error while getting next value from sequence XXDO_PICK_INTF_LINE_CMT_SEQ. Error is: '
                                            || SQLERRM);
                                        l_num_stg_line_cmt_id   := NULL;
                                END;

                                INSERT INTO xxont_pick_intf_cmt_line_stg (
                                                line_id,
                                                comment_id,
                                                warehouse_code,
                                                order_number,
                                                line_number,
                                                comment_type,
                                                comment_sequence,
                                                comment_text,
                                                process_status,
                                                request_id,
                                                creation_date,
                                                created_by,
                                                last_update_date,
                                                last_updated_by,
                                                last_update_login,
                                                source_type,
                                                SOURCE,
                                                destination)
                                     VALUES (l_num_stg_line_id, l_num_stg_line_cmt_id, SUBSTR (c_pick_rec.warehouse_code, 1, 10), SUBSTR (c_pick_rec.order_number, 1, 30), c_pick_rec.line_id, 'PACKING', l_num_comment_count, SUBSTR (c_pick_rec.line_packing_instructions, 1, 4000), gc_new_status, --'NEW',
                                                                                                                                                                                                                                                                                                      g_num_request_id, SYSDATE, g_num_user_id, SYSDATE, g_num_user_id, g_num_login_id
                                             , 'ORDER', p_source, p_dest);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    p_retcode      := g_error;
                                    p_error_buf    :=
                                           'Error occured for Order line packing instruction insert '
                                        || SQLERRM;
                                    fnd_file.put_line (fnd_file.LOG,
                                                       p_error_buf);
                                    l_chr_commit   := 'N';
                            END;
                        END IF;

                        --Begin CCR0008657
                        IF lb_is_special_vas
                        THEN
                            FOR vas_l_rec
                                IN c_vas_line (c_pick_rec.customer_code,
                                               c_pick_rec.inventory_item_id,
                                               c_pick_rec.org_id)
                            LOOP
                                INSERT INTO xxont_pick_intf_vas_line_stg (
                                                warehouse_code,
                                                order_number,
                                                line_number,
                                                vas_code,
                                                vas_description,
                                                vas_item_number,
                                                vas_label_type,
                                                process_status,
                                                request_id,
                                                creation_date,
                                                created_by,
                                                last_update_date,
                                                last_updated_by,
                                                --               last_update_login,
                                                source_type,
                                                SOURCE,
                                                destination,
                                                --       record_id,
                                                vas_free_text)
                                         VALUES (
                                                    SUBSTR (
                                                        c_pick_rec.warehouse_code,
                                                        1,
                                                        10),
                                                    SUBSTR (
                                                        c_pick_rec.order_number,
                                                        1,
                                                        30),
                                                    c_pick_rec.line_id,
                                                    SUBSTR (
                                                        vas_l_rec.vas_code,
                                                        1,
                                                        20),
                                                    SUBSTR (
                                                        vas_l_rec.description,
                                                        1,
                                                        250),
                                                    NULL,
                                                    NULL,
                                                    gc_new_status,    --'NEW',
                                                    g_num_request_id,
                                                    SYSDATE,
                                                    g_num_user_id,
                                                    SYSDATE,
                                                    g_num_user_id,
                                                    --      g_num_login_id,
                                                    'ORDER',
                                                    p_source,
                                                    p_dest,
                                                    --       xxdo_pick_intf_vas_line_seq.NEXTVAL,
                                                    vas_l_rec.vas_comments);


                                FOR params_l_rec
                                    IN (SELECT parameter_name
                                          FROM XXDO.XXD_ONT_VAS_CODE_PARAMS_T
                                         WHERE     vas_code =
                                                   vas_l_rec.vas_code
                                               AND org_id = c_pick_rec.org_id)
                                LOOP
                                    BEGIN
                                        ln_param_value   := NULL;

                                        ln_param_value   :=
                                            get_vas_param_value (
                                                c_pick_rec.order_header_id,
                                                c_pick_rec.sold_to_org_id,
                                                c_pick_rec.ship_to_org_id,
                                                c_pick_rec.inventory_item_id,
                                                params_l_rec.parameter_name);

                                        INSERT INTO XXDO.XXD_ONT_PK_INTF_P_LN_STG_T (
                                                        WAREHOUSE_CODE,
                                                        ORDER_NUMBER,
                                                        LINE_NUMBER,
                                                        VAS_CODE,
                                                        PARAMETER,
                                                        PARAMETER_VALUE,
                                                        PROCESS_STATUS,
                                                        ERROR_MESSAGE,
                                                        REQUEST_ID,
                                                        CREATION_DATE,
                                                        CREATED_BY,
                                                        LAST_UPDATE_DATE,
                                                        --   LAST_UPDATED_BY,
                                                        LAST_UPDATE_LOGIN,
                                                        SOURCE,
                                                        DESTINATION)
                                                 VALUES (
                                                            SUBSTR (
                                                                c_pick_rec.warehouse_code,
                                                                1,
                                                                10),
                                                            SUBSTR (
                                                                c_pick_rec.order_number,
                                                                1,
                                                                30),
                                                            c_pick_rec.line_id,
                                                            SUBSTR (
                                                                vas_l_rec.vas_code,
                                                                1,
                                                                20),
                                                            params_l_rec.parameter_name,
                                                            ln_param_value,
                                                            gc_new_status, --'NEW',
                                                            NULL,
                                                            g_num_request_id,
                                                            SYSDATE,
                                                            g_num_user_id,
                                                            SYSDATE,
                                                            --     g_num_user_id,
                                                            g_num_login_id,
                                                            p_source,
                                                            p_dest);
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            NULL;
                                    END;
                                END LOOP;
                            END LOOP;
                        END IF;

                        --End CCR0008657
                        /*
                                         -- Line VAS_CODE
                                          -- Modified for CCR0007638, added verify_vas_code
                                          IF c_pick_rec.vas_line_code IS NOT NULL
                                          THEN
                                             l_line_vas_code_tbl.DELETE;
                                             process_vas_code (c_pick_rec.vas_line_code,
                                                               l_line_vas_code_tbl);
                                          --verify_vas_code (c_pick_rec.customer_code,
                                          --                 l_line_vas_code_tbl);
                                          ELSE
                                             l_line_vas_code_tbl.DELETE;
                                          --verify_vas_code (c_pick_rec.customer_code,
                                          --                 l_line_vas_code_tbl);
                                          END IF;

                                          IF l_line_vas_code_tbl.COUNT > 0
                                          THEN
                                             FOR j IN l_line_vas_code_tbl.FIRST ..
                                                      l_line_vas_code_tbl.LAST
                                             LOOP
                                                BEGIN
                                                   INSERT INTO xxont_pick_intf_vas_line_stg (
                                                                  warehouse_code,
                                                                  order_number,
                                                                  line_number,
                                                                  vas_code,
                                                                  vas_description,
                                                                  vas_item_number,
                                                                  vas_label_type,
                                                                  process_status,
                                                                  request_id,
                                                                  creation_date,
                                                                  created_by,
                                                                  last_update_date,
                                                                  last_updated_by,
                                                                  source_type,
                                                                  SOURCE,
                                                                  destination,
                                                                  record_id)
                                                      SELECT SUBSTR (c_pick_rec.warehouse_code,
                                                                     1,
                                                                     10),
                                                             SUBSTR (c_pick_rec.order_number, 1, 30),
                                                             c_pick_rec.line_id,
                                                             SUBSTR (fdvl.title, 1, 10),
                                                             SUBSTR (fattach.short_text, 1, 250),
                                                             NULL,
                                                             NULL,
                                                             gc_new_status,                   --'NEW',
                                                             g_num_request_id,
                                                             SYSDATE,
                                                             g_num_user_id,
                                                             SYSDATE,
                                                             g_num_user_id,
                                                             'ORDER',
                                                             p_source,
                                                             p_dest,
                                                             xxdo_pick_intf_vas_hdr_seq.NEXTVAL
                                                        FROM fnd_documents_vl fdvl,
                                                             fnd_documents_short_text fattach
                                                       WHERE     1 = 1
                                                             AND fdvl.media_id = fattach.media_id
                                                             AND fdvl.category_description =
                                                                    'VAS Codes'
                                                             AND fdvl.title =
                                                                    l_line_vas_code_tbl (j).vas_code;
                                                EXCEPTION
                                                   WHEN OTHERS
                                                   THEN
                                                      p_retcode := g_error;
                                                      p_error_buf :=
                                                            'Error occured for VAS Code headers insert '
                                                         || SQLERRM;
                                                      fnd_file.put_line (fnd_file.LOG, p_error_buf);
                                                      l_chr_commit := 'N';
                                                END;
                                             END LOOP;
                                          END IF;
                                          */

                        /* Added for CCR0007638, Customer and SKU style VAS Codes  -- START*/
                        /*  BEGIN
                             SELECT xxdo_pick_intf_vas_hdr_seq.NEXTVAL
                               INTO l_num_stg_line_vas_id
                               FROM DUAL;

                             INSERT INTO xxont_pick_intf_vas_line_stg (
                                            warehouse_code,
                                            order_number,
                                            line_number,
                                            vas_code,
                                            vas_description,
                                            vas_item_number,
                                            vas_label_type,
                                            process_status,
                                            request_id,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_updated_by,
                                            source_type,
                                            SOURCE,
                                            destination,
                                            record_id)
                                SELECT DISTINCT
                                       SUBSTR (c_pick_rec.warehouse_code, 1, 10),
                                       SUBSTR (c_pick_rec.order_number, 1, 30),
                                       c_pick_rec.line_id,
                                       flv.tag,
                                       flv.description,
                                       NULL,
                                       NULL,
                                       'NEW',
                                       g_num_request_id,
                                       SYSDATE,
                                       g_num_user_id,
                                       SYSDATE,
                                       g_num_user_id,
                                       'ORDER',
                                       p_source,
                                       p_dest,
                                       l_num_stg_line_vas_id
                                  FROM apps.wsh_new_deliveries wnd,
                                       apps.wsh_delivery_assignments wda,
                                       apps.wsh_delivery_details wdd,
                                       apps.xxd_common_items_v xdiv,
                                       apps.fnd_lookup_values flv,
                                       apps.xxd_ra_customers_v cust
                                 WHERE     wnd.delivery_id = c_pick_rec.order_number
                                       AND wnd.organization_id =
                                              c_pick_rec.organization_id
                                       AND wnd.delivery_id = wda.delivery_id
                                       AND wda.delivery_detail_id =
                                              wdd.delivery_detail_id
                                       AND wdd.source_code = 'OE'
                                       AND wdd.source_line_id = c_pick_rec.line_id
                                       AND wdd.inventory_item_id =
                                              xdiv.inventory_item_id
                                       AND wdd.organization_id = xdiv.organization_id
                                       AND wnd.customer_id = cust.customer_id
                                       AND flv.lookup_type =
                                              'XXDO_CUSTOMER_STYLE_VAS_CODE'
                                       AND flv.LANGUAGE = 'US'
                                       AND flv.enabled_flag = 'Y'
                                       AND SYSDATE BETWEEN NVL (
                                                              flv.start_date_active,
                                                              SYSDATE - 1)
                                                       AND NVL (flv.end_date_active,
                                                                SYSDATE + 1)
                                       AND cust.customer_number =
                                              TRIM (
                                                 REGEXP_SUBSTR (lookup_code, '[^,]+'))
                                       AND xdiv.style_number =
                                              TRIM (REGEXP_SUBSTR (lookup_code,
                                                                   '[^,]+',
                                                                   1,
                                                                   2));
                          EXCEPTION
                             WHEN OTHERS
                             THEN
                                p_retcode := 2;
                                p_error_buf :=
                                      'Error occured for Customer and Style VAS Code Line Insert'
                                   || SQLERRM;
                                fnd_file.put_line (fnd_file.LOG, p_error_buf);
                                l_chr_commit := 'N';
                          END;*/

                        /* Added for CCR0007638, Customer and SKU style VAS Codes  -- END*/
                        BEGIN
                            INSERT INTO xxont_pick_intf_vas_line_stg (
                                            warehouse_code,
                                            order_number,
                                            line_number,
                                            vas_code,
                                            vas_description,
                                            vas_item_number,
                                            vas_label_type,
                                            process_status,
                                            request_id,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_updated_by,
                                            source_type,
                                            SOURCE,
                                            destination,
                                            record_id)
                                SELECT SUBSTR (c_pick_rec.warehouse_code,
                                               1,
                                               10),
                                       SUBSTR (c_pick_rec.order_number,
                                               1,
                                               30),
                                       line_id,
                                       SUBSTR (vas_code, 1, 10),
                                       SUBSTR (vas_description, 1, 250),
                                       SUBSTR (
                                           DECODE (
                                               vas_description,
                                               'Bling Machine', (SELECT flv.meaning
                                                                   FROM fnd_lookup_values flv, oe_price_adjustments opa
                                                                  WHERE     1 =
                                                                            1
                                                                        AND flv.lookup_type =
                                                                            'XXDO_ECOM_BLING'
                                                                        AND flv.LANGUAGE =
                                                                            'US'
                                                                        AND opa.line_id =
                                                                            c_pick_rec.line_id
                                                                        AND opa.list_line_type_code =
                                                                            'FREIGHT_CHARGE'
                                                                        AND opa.charge_type_code =
                                                                            'BLING'
                                                                        AND flv.lookup_code =
                                                                            opa.attribute2
                                                                        AND ROWNUM =
                                                                            1),
                                               NULL),
                                           1,
                                           30),
                                       NULL,
                                       gc_new_status,                 --'NEW',
                                       g_num_request_id,
                                       SYSDATE,
                                       g_num_user_id,
                                       SYSDATE,
                                       g_num_user_id,
                                       'ORDER',
                                       p_source,
                                       p_dest,
                                       xxdo_pick_intf_vas_hdr_seq.NEXTVAL
                                  FROM xxdo_bt_wms_vas_v
                                 WHERE     1 = 1
                                       AND delivery_id =
                                           c_pick_rec.order_number
                                       AND line_id = c_pick_rec.line_id;
                        --Added exception for change 2.3
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                p_retcode      := 2;
                                p_error_buf    :=
                                       'Error occured for Bling Machine VAS Code Line Insert'
                                    || SQLERRM;
                                fnd_file.put_line (fnd_file.LOG, p_error_buf);
                                l_chr_commit   := 'N';
                        END;
                    /*End VAS_CODE*/
                    END LOOP;
                END LOOP;
            ELSE                             --p_regenerate_xml else condition
                fnd_file.put_line (fnd_file.LOG, 'In Regenerate XML');

                IF (p_pick_num IS NOT NULL OR p_so_num IS NOT NULL)
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'In Regenerate XML, Pick ticket or Sales Order numbers are not NULL. Progressing to next validations.');

                    FOR c_regen_xml_rec
                        IN c_regen_xml (c_org_rec.organization_id)
                    LOOP
                        l_in_regen_cursor   := 'Y';
                        --Resetting variables for each iteration
                        l_ret_sts           := 0;
                        l_ret_message       := NULL;
                        msg (
                            'organization ID: ' || c_org_rec.organization_id);
                        msg ('Delivery ID: ' || c_regen_xml_rec.delivery_id);
                        --Calling the procedure to update the process status for the deliveries returned by the c_regen_xml cursor
                        upd_pick_tkt_proc_sts (c_regen_xml_rec.delivery_id,
                                               l_ret_sts,
                                               l_ret_message);

                        --If the update is not successful then write the error message into the log file and complete the program in Warning
                        IF l_ret_sts <> 0
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Regenerate XML Update Error for Delivery#'
                                || c_regen_xml_rec.delivery_id);
                            fnd_file.put_line (fnd_file.LOG,
                                               'Error is: ' || l_ret_message);
                            p_retcode   := g_warning; --Complete the program in warning
                        END IF;
                    END LOOP;

                    --If there are no records returned by the c_regen_xml cursor, complete the program in warning.
                    IF l_in_regen_cursor <> 'Y'
                    THEN
                        --l_error_msg := 'In Regenerate XML, query did not return any data. Please check if the pick ticket is WAVED/PACKED/PACKING/SHIPPED in XXDO_ONT_PICK_STATUS_ORDER table.'; --Commented by Kranthi Bollam on 22May2018
                        l_error_msg   :=
                            'In Regenerate XML, query did not return any data. Please check if the pick ticket is SHIPPED in XXDO_ONT_PICK_STATUS_ORDER table OR process_status in NEW or INPROCESS';
                        --Added by Kranthi Bollam on 22May2018
                        fnd_file.put_line (fnd_file.LOG, l_error_msg);
                        p_error_buf   := l_error_msg;
                        p_retcode     := g_warning;
                    END IF;
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'In Regenerate XML, both Pick Ticket and Sales Order Numbers are NULL. Exiting the program and completing in WARNING.');
                    p_error_buf   :=
                        'Pick Ticket and Sales Order Numbers are NULL. Exiting the program and completing in WARNING.';
                    p_retcode   := g_warning;
                END IF;
            END IF;                                  --p_regenerate_xml end if
        END LOOP;

        IF l_chr_commit = 'Y'
        THEN
            COMMIT;

            /* commit last header if that is already inserted */
            fnd_file.put_line (
                fnd_file.LOG,
                   'Commmit records for warehouse, order number: '
                || l_chr_warehouse
                || ' : '
                || l_num_order_num);
        ELSIF l_num_order_num <> -999
        THEN
            ROLLBACK;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Rollback records for warehouse, order number: '
                || l_chr_warehouse
                || ' : '
                || l_num_order_num);
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'Extracting Pick Ticket details Completed');
    EXCEPTION
        WHEN OTHERS
        THEN
            p_error_buf   := 'Unexpected error: ' || SQLERRM;
            ROLLBACK;
            p_retcode     := g_error;
            fnd_file.put_line (fnd_file.LOG, p_error_buf);
    END extract_pickticket_stage_data;

    /***********************************************************************************
     Procedure/Function Name  :  pick_extract_main
     Description              :  main procedure called by concurrent program for
                                 pick ticket extraction
    ***********************************************************************************/

    PROCEDURE pick_extract_main (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_organization IN NUMBER, p_pick_number IN NUMBER, p_so_number IN NUMBER, p_brand IN VARCHAR2, --Added for change 2.0
                                                                                                                                                                         p_sales_channel IN VARCHAR2, --Added for change 2.0
                                                                                                                                                                                                      p_regenerate_xml IN VARCHAR2, --Added for change 2.0
                                                                                                                                                                                                                                    p_debug_level IN VARCHAR2
                                 , p_source IN VARCHAR2, p_dest IN VARCHAR2)
    IS
        --Commenting the cur_org cursor for change 2.0 as this is no longer required
        /*
        CURSOR cur_org(
                       in_chr_status VARCHAR2
                      )
            IS
        SELECT DISTINCT warehouse_code,
               request_id
          FROM xxont_pick_intf_hdr_stg
         WHERE 1=1
           AND process_status = in_chr_status
           AND request_id = g_num_request_id;
        */
        l_chr_instance          VARCHAR2 (20) := NULL;
        l_dte_last_run_time     DATE;
        l_dte_next_run_time     DATE;
        l_num_conc_prog_id      NUMBER := fnd_global.conc_program_id;
        l_chr_err_buf           VARCHAR (500);
        l_chr_ret_code          NUMBER;
        lv_request_id           NUMBER;
        lv_print_msg            VARCHAR (500);
        l_chr_status            VARCHAR (5) := NULL;
        l_num_rec_count         NUMBER := 0;
        l_upd_batch_sts         NUMBER := 0;
        l_upd_batch_err_msg     VARCHAR2 (2000) := NULL;
        l_upd_batch_sts_e       NUMBER := 0;            --Added for change 2.3
        l_upd_batch_err_msg_e   VARCHAR2 (2000) := NULL; --Added for change 2.3
        lv_error_msg            VARCHAR2 (2000) := NULL; --Added for change 2.5
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'Pick Extract Main program started for Pick Ticket outbound interface:'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

        /*set the debug value - global variable. This controls the complete log throughout the program */
        IF p_debug_level = 'Y'
        THEN
            c_num_debug   := 1;
        ELSE
            c_num_debug   := 0;
        END IF;

        /* Print the input parameters */
        fnd_file.put_line (fnd_file.LOG, 'Input Parameters');
        fnd_file.put_line (fnd_file.LOG,
                           'Organization        : ' || p_organization);
        fnd_file.put_line (fnd_file.LOG,
                           'Pick Ticket         : ' || p_pick_number);
        fnd_file.put_line (fnd_file.LOG,
                           'Sales Order Number  : ' || p_so_number);
        fnd_file.put_line (fnd_file.LOG, 'Brand               : ' || p_brand);
        --Added for change 2.0
        fnd_file.put_line (fnd_file.LOG,
                           'Sales Channel       : ' || p_sales_channel); --Added for change 2.0
        fnd_file.put_line (fnd_file.LOG,
                           'Regenerate XML(Y/N) : ' || p_regenerate_xml); --Added for change 2.0
        fnd_file.put_line (fnd_file.LOG,
                           'Debug(Y/N)          : ' || p_debug_level);

        /*Get last run details for this concurrent program */
        -- Get the interface setup
        BEGIN
            l_dte_last_run_time   :=
                get_last_run_time (pn_warehouse_id    => p_organization,
                                   pv_sales_channel   => p_sales_channel);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Last run time : '
                || TO_CHAR (l_dte_last_run_time, 'DD-Mon-RRRR HH24:MI:SS'));
        EXCEPTION
            WHEN OTHERS
            THEN
                errbuf   :=
                    'Unexpected error while fetching last run: ' || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, errbuf);
        END;

        l_dte_next_run_time   := SYSDATE;

        IF l_dte_last_run_time IS NULL
        THEN
            l_dte_last_run_time   := SYSDATE - 90;
            fnd_file.put_line (
                fnd_file.LOG,
                'Last run is set to : ' || l_dte_last_run_time);
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
               'Pick Ticket Extraction procedure invoked at :'
            || TO_CHAR (SYSDATE, 'DD-Mon-RRRR HH24:MI:SS'));
        /* Invoke Pick extraction process */
        extract_pickticket_stage_data (
            p_organization     => p_organization,
            p_pick_num         => p_pick_number,
            p_so_num           => p_so_number,
            p_brand            => p_brand               --Added for change 2.0
                                         ,
            p_sales_channel    => p_sales_channel       --Added for change 2.0
                                                 ,
            p_regenerate_xml   => p_regenerate_xml      --Added for change 2.0
                                                  ,
            p_last_run_date    => l_dte_last_run_time,
            p_source           => p_source,
            p_dest             => p_dest,
            p_retcode          => l_chr_ret_code,
            p_error_buf        => l_chr_err_buf);

        IF l_chr_ret_code = 1
        THEN
            --retcode := 1; --Commented for change 2.0
            --retcode := 'WARNING'; --Commented for change 2.0
            retcode   := l_chr_ret_code;                --Added for change 2.0
            errbuf    := l_chr_err_buf;                 --Added for change 2.0
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
               'Pick Ticket Extraction procedure Completed at :'
            || TO_CHAR (SYSDATE, 'DD-Mon-RRRR HH24:MI:SS'));
        fnd_file.put_line (
            fnd_file.LOG,
               'Batching procedure started at :'
            || TO_CHAR (SYSDATE, 'DD-Mon-RRRR HH24:MI:SS'));

        --Calling procedure to do Batching by Order type(Sales Channel)--START --Added for change 2.0
        FOR i
            IN (  SELECT order_type
                    FROM xxdo.xxont_pick_intf_hdr_stg
                   WHERE     1 = 1
                         AND request_id = g_num_request_id
                         AND process_status = gc_new_status
                GROUP BY order_type
                ORDER BY order_type)
        LOOP
            proc_update_batch (pn_request_id => g_num_request_id, pv_order_type => i.order_type, x_update_status => l_upd_batch_sts
                               , x_error_message => l_upd_batch_err_msg);
        END LOOP;

        IF l_upd_batch_sts <> g_success
        THEN
            retcode   := l_upd_batch_sts;
            errbuf    := l_upd_batch_err_msg;
        END IF;

        --START - Added for change 2.3 to handle the exceptions where batch number updates failed previously and still the status is NEW
        IF p_sales_channel IS NOT NULL
        THEN
            FOR j
                IN (  SELECT order_type, request_id
                        FROM xxdo.xxont_pick_intf_hdr_stg
                       WHERE     1 = 1
                             AND request_id <> g_num_request_id
                             AND process_status = gc_new_status
                             AND batch_number IS NULL
                             AND order_type =
                                 (CASE
                                      WHEN p_sales_channel = 'ECOMM'
                                      THEN
                                          'ECOM'
                                      WHEN p_sales_channel = 'DROP-SHIP'
                                      THEN
                                          'DROPSHIP'
                                      ELSE
                                          p_sales_channel
                                  END)
                    GROUP BY order_type, request_id
                    ORDER BY order_type, request_id)
            LOOP
                proc_update_batch (pn_request_id => j.request_id, pv_order_type => j.order_type, x_update_status => l_upd_batch_sts_e
                                   , x_error_message => l_upd_batch_err_msg_e);
            END LOOP;
        END IF;

        IF l_upd_batch_sts <> g_success
        THEN
            retcode   := l_upd_batch_sts_e;
            errbuf    := l_upd_batch_err_msg_e;
        END IF;

        --END - Added for change 2.3 to handle the exceptions where batch number updates failed and still the status is NEW

        --Calling procedure to do Batching --END
        fnd_file.put_line (
            fnd_file.LOG,
               'Batching procedure Completed at :'
            || TO_CHAR (SYSDATE, 'DD-Mon-RRRR HH24:MI:SS'));

        /* update the last run details if the program is not run with specific inputs */
        IF (p_pick_number IS NULL --AND p_organization IS NULL --Commented for change 2.0 --Not Required(There is no chance of Org being NULL as it is mandatory parameter)
                                  AND p_so_number IS NULL AND p_regenerate_xml = 'N' --Added for change 2.0 --Do not update last update date if the program is run in Regenerate XML Mode
                                                                                    )
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Updating the last run to : ' || l_dte_next_run_time);

            BEGIN
                set_last_run_time (pn_warehouse_id    => p_organization,
                                   pv_sales_channel   => p_sales_channel,
                                   pd_last_run_date   => l_dte_next_run_time);
            EXCEPTION
                WHEN OTHERS
                THEN
                    errbuf   :=
                           'Unexpected error while updating the next run time : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, errbuf);
            END;
        END IF;

        --Added for change 2.5 --START
        fnd_file.put_line (
            fnd_file.LOG,
               'Calling VALIDATE_CROSSDOCK_DELIVERIES Procedure - START. Timestamp:'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
        validate_crossdock_deliveries (pn_org_id          => p_organization,
                                       pv_error_message   => lv_error_msg);
        fnd_file.put_line (
            fnd_file.LOG,
               'Calling VALIDATE_CROSSDOCK_DELIVERIES Procedure - END. Timestamp:'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
        --Added for change 2.5 --END
        fnd_file.put_line (
            fnd_file.LOG,
               'Pick Extract Main program Completed for Pick Ticket outbound interface:'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
    EXCEPTION
        WHEN OTHERS
        THEN
            --msg('Error occured in Main extract at step ' || lv_print_msg || '-' || SQLERRM);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error occured in Main pick_extract_main procedure at step '
                || lv_print_msg
                || '-'
                || SQLERRM);
            retcode   := g_error;
            errbuf    := SQLERRM;
    END pick_extract_main;

    --Added below procedure for change 2.5 to back order crossdock deliveries
    --Not able to backorder crossdock lines using standard api "wsh_deliveries_pub.delivery_action".Only lines are getting unassigned from delivery but are not backordering.
    --Using data script provided in SR "SR 3-19109257261 : DG! Not able to ship confirm the line due to line status is "Planned for Crossdocking"" to backorder crossdock lines

    PROCEDURE backorder_crossdock_deliveries (pn_org_id IN NUMBER)
    IS
        CURSOR del_details_cur IS
              SELECT DISTINCT wdv.delivery_id, wdv.delivery_detail_id, wdv.source_line_id,
                              wdv.organization_id
                FROM apps.wsh_deliverables_v wdv
               WHERE     wdv.organization_id = pn_org_id
                     AND wdv.source_code = 'OE'
                     AND wdv.released_status IN ('Y', 'S')
                     AND EXISTS
                             (SELECT 1
                                FROM apps.wsh_delivery_details wd, apps.wsh_delivery_assignments wda
                               WHERE     wd.move_order_line_id IS NULL
                                     AND wd.released_status IN ('Y', 'S')
                                     AND wd.source_code = 'OE'
                                     AND wd.delivery_detail_id =
                                         wda.delivery_detail_id
                                     AND wda.delivery_id = wdv.delivery_id)
            ORDER BY wdv.delivery_id, wdv.source_line_id;

        CURSOR reservations_cur (cn_demand_source_line_id NUMBER)
        IS
            SELECT mr.*
              FROM apps.mtl_reservations mr
             WHERE mr.demand_source_line_id = cn_demand_source_line_id;

        lv_proc_name     VARCHAR2 (30) := 'BACKORDER_CROSSDOCK_DELIVERIES';
        l_rsv_rec        inv_reservation_global.mtl_reservation_rec_type;
        ln_msg_count     NUMBER;
        lv_msg_data      VARCHAR2 (2000);
        ln_rsv_id        NUMBER;
        l_dummy_sn_tbl   inv_reservation_global.serial_number_tbl_type;
        lv_status        VARCHAR2 (1);
    BEGIN
        FOR del_details_rec IN del_details_cur
        LOOP
            /* Unassign delivery from the details */
            BEGIN
                UPDATE wsh_delivery_assignments
                   SET delivery_id = NULL, parent_delivery_detail_id = NULL, last_update_date = SYSDATE,
                       last_updated_by = g_num_user_id
                 WHERE delivery_detail_id =
                       del_details_rec.delivery_detail_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error while unassigning delivery from the details: '
                        || SQLERRM);
            END;

            /* Backorder the delivery details */
            BEGIN
                UPDATE wsh_delivery_details
                   SET released_status = 'B', subinventory = NULL, locator_id = NULL,
                       move_order_line_id = NULL, picked_quantity = NULL, shipped_quantity = NULL,
                       lot_number = NULL, preferred_grade = NULL, sublot_number = NULL,
                       revision = NULL, serial_number = NULL, batch_id = NULL,
                       lpn_id = NULL, transaction_id = NULL, transaction_temp_id = NULL,
                       last_update_date = SYSDATE, last_updated_by = g_num_user_id
                 WHERE     delivery_detail_id =
                           del_details_rec.delivery_detail_id
                       AND organization_id = del_details_rec.organization_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error while backordering delivery details: '
                        || SQLERRM);
            END;

            /* Delete the pick tasks */
            BEGIN
                DELETE FROM
                    apps.mtl_material_transactions_temp
                      WHERE     trx_source_line_id =
                                del_details_rec.source_line_id
                            AND organization_id =
                                del_details_rec.organization_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Error while deleating pick tasks: ' || SQLERRM);
            END;

            /* Close the move order lines by setting status to 5 */
            BEGIN
                UPDATE apps.mtl_txn_request_lines
                   SET line_status = 5, last_update_date = SYSDATE, last_updated_by = g_num_user_id
                 WHERE     txn_source_line_id =
                           del_details_rec.source_line_id
                       AND organization_id = del_details_rec.organization_id
                       AND line_status = 7;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Error while closing Move Order Lines: ' || SQLERRM);
            END;

            BEGIN
                UPDATE apps.wsh_new_deliveries
                   SET status_code = 'CL', last_update_date = SYSDATE, last_updated_by = g_num_user_id
                 WHERE delivery_id = del_details_rec.delivery_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Error while Closing Delivery: ' || SQLERRM);
            END;

            /* Delete the reservations */
            FOR reservations_rec
                IN reservations_cur (del_details_rec.source_line_id)
            LOOP
                fnd_global.apps_initialize (
                    user_id        => g_num_user_id,
                    resp_id        => g_num_resp_id,
                    resp_appl_id   => g_num_resp_appl_id);
                l_rsv_rec.reservation_id   := reservations_rec.reservation_id;
                inv_reservation_pub.delete_reservation (
                    p_api_version_number   => 1.0,
                    p_init_msg_lst         => fnd_api.g_true,
                    x_return_status        => lv_status,
                    x_msg_count            => ln_msg_count,
                    x_msg_data             => lv_msg_data,
                    p_rsv_rec              => l_rsv_rec,
                    p_serial_number        => l_dummy_sn_tbl);

                IF lv_status = fnd_api.g_ret_sts_success
                THEN
                    fnd_file.put_line (fnd_file.LOG, 'Reservations Deleted');
                ELSE
                    IF ln_msg_count >= 1
                    THEN
                        FOR i IN 1 .. ln_msg_count
                        LOOP
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   i
                                || '. '
                                || SUBSTR (
                                       fnd_msg_pub.get (
                                           p_encoded => fnd_api.g_false),
                                       1,
                                       255));
                        END LOOP;
                    END IF;
                END IF;

                COMMIT;
            END LOOP;

            COMMIT;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error in '
                || lv_proc_name
                || ' procedure. Error is: '
                || SQLERRM);
    END backorder_crossdock_deliveries;

    --Added below procedure for change 2.5 to send email if any crossdock deliveries are detected and then back order them

    PROCEDURE validate_crossdock_deliveries (
        pn_org_id          IN     NUMBER,
        pv_error_message      OUT VARCHAR2)
    IS
        lv_proc_name         VARCHAR2 (30) := 'VALIDATE_CROSSDOCK_DELIVERIES';
        ln_count_rec         NUMBER;
        ln_request_id        NUMBER;
        lb_concreqcallstat   BOOLEAN := FALSE;
        lv_phasecode         VARCHAR2 (100) := NULL;
        lv_statuscode        VARCHAR2 (100) := NULL;
        lv_devphase          VARCHAR2 (100) := NULL;
        lv_devstatus         VARCHAR2 (100) := NULL;
        lv_returnmsg         VARCHAR2 (200) := NULL;
        ln_query_id          NUMBER;
    BEGIN
        SELECT COUNT (*)
          INTO ln_count_rec
          FROM apps.wsh_deliverables_v wdv, apps.hz_parties hp, hz_cust_accounts hca,
               oe_order_headers_all ooh
         WHERE     wdv.organization_id = pn_org_id
               AND wdv.source_code = 'OE'
               AND wdv.released_status IN ('Y', 'S')
               AND wdv.move_order_line_id IS NULL
               AND wdv.customer_id = hca.cust_account_id
               AND hp.party_id = hca.party_id
               AND wdv.source_header_id = ooh.header_id;

        IF ln_count_rec > 0
        THEN
            BEGIN
                SELECT query_id
                  INTO ln_query_id
                  FROM xxdo.xxdo_common_daily_status_tbl
                 WHERE     email_attachment_file_name =
                           'US1_PLANNED_CROSSDOCKING_STATUS_ORDERS'
                       AND enabled_flag = 'Yes'
                       AND TRUNC (SYSDATE) BETWEEN NVL (effective_start_date,
                                                        TRUNC (SYSDATE))
                                               AND NVL (effective_end_date,
                                                        TRUNC (SYSDATE));
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_query_id   := NULL;
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'No query id found to submit alert ' || SQLERRM);
                WHEN TOO_MANY_ROWS
                THEN
                    ln_query_id   := NULL;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'More than one query id found to submit alert '
                        || SQLERRM);
                WHEN OTHERS
                THEN
                    ln_query_id   := NULL;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error ocurred when fectching query id to submit alert: '
                        || SQLERRM);
            END;

            IF ln_query_id IS NOT NULL
            THEN
                apps.fnd_global.apps_initialize (g_num_user_id,
                                                 g_num_resp_id,
                                                 g_num_resp_appl_id);
                --Submitting "Deckers Daily Satus Monitoring Report" concurrent program
                ln_request_id   :=
                    fnd_request.submit_request (
                        application   => 'XXDO',
                        program       => 'XXDO_COMMON_DAILY_STATUS',
                        description   =>
                            'Deckers Daily Status Monitoring Report',
                        start_time    => SYSDATE,
                        sub_request   => FALSE,
                        argument1     => ln_query_id                --Query ID
                                                    );
                COMMIT;

                IF ln_request_id = 0
                THEN
                    pv_error_message   :=
                        SUBSTR (
                               'Error while submitting Deckers Daily Status Monitoring Report. Error is: '
                            || SQLERRM,
                            1,
                            2000);
                ELSE
                    LOOP
                        lb_concreqcallstat   :=
                            apps.fnd_concurrent.wait_for_request (
                                ln_request_id,
                                5,         -- wait 5 seconds between db checks
                                0,
                                lv_phasecode,
                                lv_statuscode,
                                lv_devphase,
                                lv_devstatus,
                                lv_returnmsg);
                        EXIT WHEN lv_devphase = 'COMPLETE';
                    END LOOP;
                END IF;
            END IF;

            --wait for the program to complete
            --call procedure backorder_crossdock_deliveries to backorder deliveries
            backorder_crossdock_deliveries (pn_org_id);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_message   := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error in '
                || lv_proc_name
                || 'Error is: '
                || pv_error_message);
    END validate_crossdock_deliveries;
END xxd_wms_hj_int_pkg;
/


--
-- XXD_WMS_HJ_INT_PKG  (Synonym) 
--
CREATE OR REPLACE SYNONYM SOA_INT.XXD_WMS_HJ_INT_PKG FOR APPS.XXD_WMS_HJ_INT_PKG
/


GRANT DEBUG ON APPS.XXD_WMS_HJ_INT_PKG TO APPSRO
/

GRANT EXECUTE, DEBUG ON APPS.XXD_WMS_HJ_INT_PKG TO SOA_INT
/

GRANT EXECUTE ON APPS.XXD_WMS_HJ_INT_PKG TO XXDO
/
