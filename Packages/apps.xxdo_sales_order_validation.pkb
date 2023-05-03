--
-- XXDO_SALES_ORDER_VALIDATION  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:19 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_SALES_ORDER_VALIDATION"
--****************************************************************************************************
--*  NAME       : XXDO_SALES_ORDER_VALIDATION
--*  APPLICATION: Oracle Order Management
--*
--*  AUTHOR     : Sivakumar Boothathan
--*  DATE       : 01-MAR-2017
--*
--*  DESCRIPTION: This package will do the following
--*               A. Intro Season Validation : To check the intro season for the SKU's and take an action
--*                  an action is either to mark them as success or failed if the order line request
--*                  dates is before the intro season date
--*               B. Order type grouping : Based on a mapping the order type will be updated either as
--*                  pre-season or in-season order type
--*  REVISION HISTORY:
--*  Change Date     Version          By                  Change Description
--****************************************************************************************************
--*  01-MAR-2017     1.0         Siva Boothathan          Initial Creation
--*  13-DEC-2017     1.1         Siva Boothathan          CCR0006890-EDI 860s stuck in IFACE for Wholesale - US
--*  05-JAN-2018     1.2         Siva Boothathan          Changes to allow extensions even with Reservation
--*  05-JAN-2018     1.3         Siva Boothathan          Use ATS date instead of intro date
--*  28-FEB-2018     1.4         Infosys                  Exclude Order types from Duplicate check
--*  29-Jan-2018     1.5         Viswanathan Pandian      Modified for CCR0006889 to revert code
--*                                                       changes done as part of CCR0006663
--*  24-MAY-2018     1.6         Infosys                  Cancel date validation
--*  18-Jul-2018     1.7         Viswanathan Pandian      Modified for CCR0007226 to delete iface records
--*                                                       for inactive skus and capture them in a table
--*  27-Nov-2018     1.8         Gaurav Joshi             Modified for CCR0007582 - EBS:O2F: Order Import Defects
--*  02-Feb-2018     1.9         Gaurav Joshi             Modified for CCR0007689 Cancel Date less than Request Date
--*  26-Aug-2019     2.0         Viswanathan Pandian      Modified for CCR0008175
--*  21-Apr-2020     2.1         Sivakumar Boothathan     Modified for CCR0008604 - To enable deckersb2b for drop shipments
--*  17-Jun-2020     2.2         Aravind Kannuri          Modified for CCR0008488 - EDI 850 and 860
--* 18-Aug-2020      2.3         Gaurav Joshi             CCR0008657 Implement new VAS, shipping and packing instructions logic
--*  14-Jan-2021     2.4         Viswanathan Pandian      Modified for CCR0009130 for B2B Order
--*  12-FEB-2021     2.5         Aravind Kannuri          Modified for CCR0009192
--*  22-JUN-2021     2.6         Greg Jensen              Modified for CCR0009335
--*  19-JUL-2021     2.7         Aravind Kannuri          Modified for CCR0009429
--*  01-Sep-2021     2.8         Shivanshu Talwar         Modified for CCR0009525
--*  01-Sep-2021     2.9         Laltu Sah                Modified for CCR0009954
--*  15-Sep-2022     2.10        Shivanshu Talwar         Modified for CCR0010110 : Brand SKU Mismatch
--*  01-Sep-2022     2.11        Laltu Sah                Modified for CCR0010148
--*  01-Nov-2022     2.12        Laltu Sah                Modified for CCR0010028
--*  11-Nov-2022     2.13        Shivanshu                Modified for CCR0010295: SKU brand validation in order import pre-validation
--*  12-Jan-2023     2.14        Viswanathan Pandian      Modified for CCR0010407
--*  23-Mar-2023     2.15        Thirupathi Gajula        Modified for CCR0010488: Update Brand SKU mismatch error in Line level
--****************************************************************************************************
IS
    -- Start of changes By Siva Boothathan for CCR :CCR0006663
    gn_master_org_id   NUMBER;
    gn_batch_user_id   NUMBER;
    gn_request_id      NUMBER := fnd_global.conc_request_id;

    -- End of changes By Siva Boothathan for CCR :CCR0006663
    -------------------------------------------------------------
    -- Control procedure to navigate the control for the package
    -- Input Operating Unit
    -- Functionality :
    -- A. The input : Operating Unit is taken as the input Parameter
    -- B. Execute the delete scripts which will find the records
    -- in the interface table with the change sequence and delete
    -- C. Call the next procedures for ATP, LAD etc.
    -------------------------------------------------------------

    --added Start as part of 2.8
    -------------------------------------------------
    --** This procedure will be called
    --** to apply/release the EDI 860 holds on the orders
    -----------------------------------------------------
    PROCEDURE xx_apply_release_hold (pv_hold_release          VARCHAR2,
                                     pn_hold_id               NUMBER,
                                     pn_header_id             NUMBER,
                                     pv_release_reason_code   VARCHAR2,
                                     pv_release_comment       VARCHAR2)
    AS
        l_line_rec              oe_order_pub.line_rec_type;
        l_header_rec            oe_order_pub.header_rec_type;
        l_action_request_tbl    oe_order_pub.request_tbl_type;
        l_request_rec           oe_order_pub.request_rec_type;
        l_line_tbl              oe_order_pub.line_tbl_type;
        l_hold_source_rec       oe_holds_pvt.hold_source_rec_type;
        l_order_tbl_type        oe_holds_pvt.order_tbl_type;
        ln_hold_msg_count       NUMBER := 0;
        lc_hold_msg_data        VARCHAR2 (2000);
        lc_hold_return_status   VARCHAR2 (20);
        lc_api_return_status    VARCHAR2 (1);
        ln_msg_count            NUMBER := 0;
        ln_msg_index_out        NUMBER;
        ln_record_count         NUMBER := 0;
        lc_msg_data             VARCHAR2 (2000);
        lc_error_message        VARCHAR2 (2000);
        lc_return_status        VARCHAR2 (20);
        lc_delink_status        VARCHAR2 (1);
        lc_lock_status          VARCHAR2 (1);
        lc_status               VARCHAR2 (1);
        lc_wf_status            VARCHAR2 (1);
    BEGIN
        lc_error_message   := NULL;
        lc_return_status   := NULL;

        IF pv_hold_release = 'HOLD'
        THEN
            -- Apply Calloff Order Line Hold
            l_hold_source_rec.hold_id            := pn_hold_id;
            l_hold_source_rec.hold_entity_code   := 'O';
            l_hold_source_rec.hold_entity_id     := pn_header_id;
            l_hold_source_rec.hold_comment       := pv_release_comment;
            oe_holds_pub.apply_holds (
                p_api_version        => 1.0,
                p_validation_level   => fnd_api.g_valid_level_full,
                p_hold_source_rec    => l_hold_source_rec,
                x_msg_count          => ln_hold_msg_count,
                x_msg_data           => lc_hold_msg_data,
                x_return_status      => lc_hold_return_status);

            -- debug_msg ('Apply Hold Status = ' || lc_hold_return_status);

            IF lc_hold_return_status = 'S'
            THEN
                lc_delink_status   := 'S';
            ELSE
                FOR i IN 1 .. oe_msg_pub.count_msg
                LOOP
                    oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lc_hold_msg_data
                                    , p_msg_index_out => ln_msg_index_out);
                    lc_error_message   :=
                        lc_error_message || lc_hold_msg_data;
                END LOOP;

                --debug_msg ('Hold API Error = ' || lc_error_message);
                ROLLBACK;
            -- If unable to apply hold, skip and continue
            END IF;
        END IF;


        IF pv_hold_release = 'RELEASE'
        THEN
            l_order_tbl_type (1).header_id   := pn_header_id;

            -- Call Process Order to release hold
            oe_holds_pub.release_holds (p_api_version => 1.0, p_init_msg_list => fnd_api.g_true, p_commit => fnd_api.g_false, p_order_tbl => l_order_tbl_type, p_hold_id => pn_hold_id, p_release_reason_code => pv_release_reason_code, p_release_comment => pv_release_comment, x_return_status => lc_return_status, x_msg_count => ln_msg_count
                                        , x_msg_data => lc_msg_data);

            fnd_file.put_line (fnd_file.LOG,
                               'Hold Release Status = ' || lc_return_status);

            IF lc_return_status = 'S'
            THEN
                fnd_file.put_line (fnd_file.LOG, 'Released Hold');
            ELSE
                FOR i IN 1 .. oe_msg_pub.count_msg
                LOOP
                    oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lc_msg_data
                                    , p_msg_index_out => ln_msg_index_out);
                    lc_error_message   := lc_error_message || lc_msg_data;
                END LOOP;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'Hold Release Failed: ' || lc_error_message);
            END IF;
        END IF;
    END xx_apply_release_hold;

    --End as part of 2.8

    ----------------------------------
    --** This procedure will be called from concurent program
    --** to release the order header holds
    ----------------------------------
    --Start as part of 2.8
    PROCEDURE release_hold_proc (p_errbuf OUT VARCHAR2, p_retcode OUT VARCHAR2, p_operating_unit IN NUMBER
                                 , p_osid IN NUMBER)
    IS
        lv_release_reason_code   VARCHAR2 (240) := 'OM_MODIFY'; -- 'Order Modify Process Success';
        lv_release_comment       VARCHAR2 (240);

        -------------------------------------------------------
        -- Cursor to get orders for Released the HOLD Deckers EDI 860 Hold -- as part added for 2.8
        -------------------------------------------------------
        CURSOR cur_get_order_release IS
            SELECT ohd.hold_id, oha.header_id
              FROM oe_order_holds_all oh, oe_order_headers_all oha, oe_hold_sources_all ohsa,
                   oe_hold_definitions ohd
             WHERE     1 = 1
                   AND oha.org_id = p_operating_unit
                   AND oha.order_source_id = p_osid
                   AND oha.org_id = oha.org_id
                   AND oh.released_flag = 'N'
                   AND ohd.name = 'Deckers EDI 860 Hold'
                   AND oh.header_id = oha.header_id
                   AND oh.hold_source_id = ohsa.hold_source_id
                   AND ohsa.hold_id = ohd.hold_id
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.oe_headers_iface_all ooh1
                             WHERE ooh1.orig_sys_document_ref =
                                   oha.orig_sys_document_ref);
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'Program Started.' || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

        lv_release_comment   :=
            'EDI 860 HOLD RELEASE , REQ ID' || gn_request_id;

        ------------------------------------------
        ---860 cusror to call hold proc
        ------------------------------------------
        FOR rec_get_order_release IN cur_get_order_release
        LOOP
            fnd_file.put_line (
                fnd_file.LOG,
                'Inside Hold Cursor Header id ' || rec_get_order_release.header_id);
            xx_apply_release_hold ('RELEASE',
                                   rec_get_order_release.hold_id,
                                   rec_get_order_release.header_id,
                                   lv_release_reason_code,
                                   lv_release_comment);
        END LOOP;
    END release_hold_proc;

    --End as part of 2.8

    PROCEDURE main_control (p_errbuf OUT VARCHAR2, p_retcode OUT VARCHAR2, p_operating_unit IN NUMBER
                            , p_osid IN NUMBER)
    IS
        ln_count   NUMBER := 0;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'MAIN_CONTROL Start');
        cancel_date_validation (p_operating_unit, p_osid); --Added by Infosys for CCR0007225

        -----------------------------------------------------
        -- Check for Duplicate
        ----------------------------------------------------
        order_header_duplicate (p_operating_unit, p_osid);

        -----------------------------------------------------
        -- Check for Brand Mismatch CCR0010110
        ----------------------------------------------------
        order_brand_mismatch (p_operating_unit, p_osid);

        -------------------------------------------------------
        -- Calling the order_line_validation
        -------------------------------------------------------
        order_line_validation (p_operating_unit, p_osid);

        -------------------------------------------------------
        -- Deriving B2B2C order type
        -- Added for CCR0008604
        -------------------------------------------------------
        get_b2b2c_ordertype (p_operating_unit, p_osid);

        -------------------------------------------------------
        -- Deriving SPS order type
        -------------------------------------------------------
        edi_850_sps_validation (p_operating_unit, p_osid);

        --------------------------------------------------------
        -- Deriving Non SPS order type
        --------------------------------------------------------
        get_order_type (p_operating_unit, p_osid);

        -------------------------------------------------------
        -- Calling EDI 860 Validation
        -------------------------------------------------------
        edi_860_validation (p_operating_unit, p_osid);

        -------------------------------------------------------
        -- Calling EDI 855 Validation
        -------------------------------------------------------
        edi_855_validation (p_operating_unit, p_osid);

        -------------------------------------------------------
        -- Calling EDI 860 Exclusion
        -------------------------------------------------------
        edi_860_exclusion (p_operating_unit, p_osid);

        -------------------------------------------------------
        -- Calling Line Status Check --Added for CCR0009192
        -------------------------------------------------------
        ord_line_status_chk (p_operating_unit, p_osid);

        -------------------------------------------------------
        -- Calling Order header Hold  --Added for CCR0009525-- 2.8
        -------------------------------------------------------
        ord_header_hold_chk (p_operating_unit, p_osid);


        fnd_file.put_line (fnd_file.LOG, 'MAIN_CONTROL End');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in MAIN_CONTROL = ' || SQLERRM);
    END main_control;

    -------------------------------------------------------------
    -- Procedure to perform the order line validation to check brand mismatch
    -- don't mark the error flag
    -- This procedure has been added W.r.t CCR - CCR0010110
    -------------------------------------------------------------

    PROCEDURE order_brand_mismatch (p_operating_unit   IN NUMBER,
                                    p_osid             IN NUMBER)
    IS
        -----------------------------------
        -- Declaring Local variables
        -- visible inside the procedure
        -----------------------------------
        v_ou_id        NUMBER := p_operating_unit;
        v_os_id        NUMBER := p_osid;
        ln_brand_cnt   NUMBER := 0;

        -----------------------------------------------------------------------------
        -- Cursor to get the list of order headers and lines in the interface table
        -----------------------------------------------------------------------------
        CURSOR cur_get_orsdr_data (v_ou_id IN NUMBER, v_os_id IN NUMBER)
        IS
            SELECT /*+ parallel(2) */
                   DISTINCT ooha.customer_po_number po, ooha.orig_sys_document_ref osdr
              FROM apps.oe_headers_iface_all ooha, apps.oe_lines_iface_all oola
             WHERE     ooha.orig_sys_document_ref =
                       oola.orig_sys_document_ref
                   AND ooha.org_id = oola.org_id
                   AND ooha.request_id IS NULL
                   AND ooha.error_flag IS NULL
                   AND ooha.org_id = v_ou_id
                   AND ooha.order_source_id = v_os_id;
    ----------------------------------------------------------
    -- Geeting all orders to check the brand mismatch
    ---------------------------------------------------------
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'ORDER_BRAND_MISMATCH Start : '
            || TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));
        fnd_file.put_line (
            fnd_file.output,
            '---------------------------------------------------');

        --------------------------------------------------
        -- Start looping the cursor : cur_get_iface_data
        --------------------------------------------------
        FOR c_cur_get_orsdr_data IN cur_get_orsdr_data (v_ou_id, v_os_id)
        LOOP
            --------------------------------------------------------
            -- updating the orig_sys_document_ref data to error
            --------------------------------------------------------
            /* SELECT COUNT (DISTINCT brand)
               INTO ln_brand_cnt
               FROM apps.oe_lines_iface_all ola, apps.xxd_common_items_v ms
              WHERE     1 = 1
                    AND orig_sys_document_ref = c_cur_get_orsdr_data.osdr
                    AND ola.inventory_item_id = ms.inventory_item_id
                    AND organization_id = 106;*/
            --Commented as part of CCR0010295

            --Added as part of CCR0010295
            SELECT COUNT (1)
              INTO ln_brand_cnt
              FROM apps.oe_lines_iface_all ola, apps.xxd_common_items_v ms, hz_cust_accounts hca
             WHERE     1 = 1
                   AND orig_sys_document_ref = c_cur_get_orsdr_data.osdr
                   AND ola.inventory_item_id = ms.inventory_item_id
                   AND ola.sold_to_org_id = hca.cust_account_id
                   AND hca.attribute1 <> ms.brand
                   AND organization_id = gn_master_org_id;

            --Added as part of CCR0010295

            IF ln_brand_cnt > 0
            THEN
                fnd_file.put_line (
                    fnd_file.output,
                       'PO Number for Brand Mismatch Validation :'
                    || c_cur_get_orsdr_data.osdr);

                UPDATE apps.oe_headers_iface_all
                   SET error_flag = 'Y', request_id = 0000090, last_update_date = SYSDATE,
                       last_updated_by = gn_batch_user_id
                 WHERE     orig_sys_document_ref = c_cur_get_orsdr_data.osdr
                       AND error_flag IS NULL
                       AND request_id IS NULL;

                FOR line_brand_err
                    IN (SELECT ola.orig_sys_document_ref, ola.line_number -- START Added as part of CCR0010488
                          FROM apps.oe_lines_iface_all ola, apps.xxd_common_items_v ms, hz_cust_accounts hca
                         WHERE     1 = 1
                               AND orig_sys_document_ref =
                                   c_cur_get_orsdr_data.osdr
                               AND ola.inventory_item_id =
                                   ms.inventory_item_id
                               AND ola.sold_to_org_id = hca.cust_account_id
                               AND hca.attribute1 <> ms.brand
                               AND organization_id = gn_master_org_id)
                LOOP
                    BEGIN
                        UPDATE apps.oe_lines_iface_all
                           SET error_flag = 'Y', request_id = 0000090, last_update_date = SYSDATE,
                               last_updated_by = gn_batch_user_id
                         WHERE     orig_sys_document_ref =
                                   line_brand_err.orig_sys_document_ref
                               AND line_number = line_brand_err.line_number
                               AND error_flag IS NULL
                               AND request_id IS NULL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Exception in ORDER_BRAND_MISMATCH for Order Doc Number : '
                                || line_brand_err.orig_sys_document_ref
                                || 'Line Number : '
                                || line_brand_err.line_number);
                    END;
                END LOOP;                   -- END Added as part of CCR0010488
            END IF;
        END LOOP;

        --End Added for CCR0009429
        --------------------------------------------
        -- Committing the transacion for the update
        --------------------------------------------
        COMMIT;
        ----------------------------------
        -- Print the output for the values
        ----------------------------------


        fnd_file.put_line (
            fnd_file.output,
               '------------END ORDER_BRAND_MISMATCH-----'
            || TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));

        ------------------------
        -- End of the procedure
        ------------------------
        fnd_file.put_line (fnd_file.LOG, 'ORDER_BRAND_MISMATCH End');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'MAIN Others Exception in ORDER_BRAND_MISMATCH = ' || SQLERRM);
    END order_brand_mismatch;

    -------------------------------------------------------------
    -- Procedure to perform the order line validation
    -- This procedure does the below
    -- A. For the eligable records of Operating unit and Order source
    -- B. The lines will be selected and the SKU's will be
    -- validated with the below logic i.e
    -- It checks for the intro season  in mtl_system_items_b
    -- The intro season's start date should be taken and validated
    -- with the request date and if the request date is before
    -- the item's intro date then mark the line as error
    -- don't mark the error flag
    -------------------------------------------------------------
    PROCEDURE order_line_validation (p_operating_unit   IN NUMBER,
                                     p_osid             IN NUMBER)
    IS
        -----------------------------------
        -- Declaring Local variables
        -- visible inside the procedure
        -----------------------------------
        v_ou_id                   NUMBER := p_operating_unit;
        v_os_id                   NUMBER := p_osid;
        -- Start changes for CCR0009429
        ln_customer_id            NUMBER;
        ld_request_date           DATE;
        ld_ats_date               DATE;
        ld_intro_date             DATE;
        ld_ats_intro_date         DATE;
        lv_ats_day                VARCHAR2 (50) := NULL;
        ln_buffer_days            NUMBER := 0;
        ln_ats_wknd_exists        NUMBER := 0;
        ln_cust_eligible_exists   NUMBER := 0;

        -- End changes for CCR0009429

        -----------------------------------------------------------------------------
        -- Cursor to get the list of order headers and lines in the interface table
        -----------------------------------------------------------------------------
        CURSOR cur_get_iface_data (v_ou_id IN NUMBER, v_os_id IN NUMBER)
        IS
            SELECT /*+ parallel(2) */
                   ooha.customer_po_number po, ooha.orig_sys_document_ref osdr, oola.orig_sys_line_ref oslr,
                   msi.segment1 sku, msi.attribute16 intro_season, TRUNC (fnd_date.canonical_to_date (msi.attribute24), 'MM') intro_date,
                   TRUNC (ooha.request_date) request_date, --Start Added for CCR0009429
                                                           TRUNC (fnd_date.canonical_to_date (msi.attribute25)) ats_date, ooha.sold_to_org_id customer_id
              --End Added for CCR0009429
              FROM apps.oe_headers_iface_all ooha, apps.oe_lines_iface_all oola, apps.mtl_system_items msi
             WHERE     ooha.orig_sys_document_ref =
                       oola.orig_sys_document_ref
                   AND ooha.org_id = oola.org_id
                   AND ooha.request_id IS NULL
                   AND ooha.error_flag IS NULL
                   AND oola.inventory_item_id = msi.inventory_item_id
                   AND msi.organization_id = gn_master_org_id
                   AND ooha.org_id = v_ou_id
                   AND ooha.order_source_id = v_os_id
                   --------------------------------------------------------------
                   -- Changes added By Sivakumar Boothathan to use ATS date
                   -- Instead of Intro Date
                   -- Logic is request date is checked against the Attribute25
                   -- Which is the ATS date and if Attribute25 is null then validate
                   -- the request date against Attribute24 and if null then
                   -- validate aginst request date
                   --------------------------------------------------------------
                   --AND TRUNC (ooha.request_date) <
                   --      NVL (
                   --         TRUNC (TO_DATE (msi.attribute24, 'RRRR/MM/DD'),
                   --                'month'),
                   --         TRUNC (ooha.request_date));
                   AND TRUNC (ooha.request_date) <
                       NVL (
                           NVL (
                               fnd_date.canonical_to_date (msi.attribute25),
                               TRUNC (
                                   fnd_date.canonical_to_date (
                                       msi.attribute24),
                                   'MM')),
                           TRUNC (ooha.request_date));
    ----------------------------------------------------------
    -- Beginning of the procedure and the function here is to
    -- mark the records from the cursor as error_flag = 'Y'
    -- and request id as 0000000 so that the user knows the
    -- reason for the error line which is the item failed
    ---------------------------------------------------------
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'ORDER_LINE_VALIDATION Start');
        fnd_file.put_line (
            fnd_file.output,
            'List Of Order Lines Ordered Before The Intro Season');
        fnd_file.put_line (
            fnd_file.output,
            '---------------------------------------------------');

        --------------------------------------------------
        -- Start looping the cursor : cur_get_iface_data
        --------------------------------------------------
        FOR c_cur_get_iface_data IN cur_get_iface_data (v_ou_id, v_os_id)
        LOOP
            --Start Changes for CCR0009429
            ln_customer_id      := c_cur_get_iface_data.customer_id;
            ld_request_date     := c_cur_get_iface_data.request_date;
            ld_ats_date         := c_cur_get_iface_data.ats_date;
            ld_intro_date       := c_cur_get_iface_data.intro_date;
            ld_ats_intro_date   := NVL (ld_ats_date, ld_intro_date);

            fnd_file.put_line (
                fnd_file.output,
                   'customer_id :'
                || ln_customer_id
                || ' and ats_intro_date :'
                || ld_ats_intro_date);
            fnd_file.put_line (
                fnd_file.output,
                   'request_date :'
                || ld_request_date
                || ' and ats_date :'
                || ld_ats_date
                || ' and intro_date :'
                || ld_intro_date);

            IF ld_ats_intro_date IS NOT NULL
            THEN
                -- Rule1: ATS Date Weekend Check
                BEGIN
                    SELECT CASE
                               WHEN TO_CHAR (ld_ats_intro_date, 'DY') IN
                                        ('SAT')
                               THEN
                                   'WKND_SAT'
                               WHEN TO_CHAR (ld_ats_intro_date, 'DY') IN
                                        ('SUN')
                               THEN
                                   'WKND_SUN'
                               ELSE
                                   'WK_DAY'
                           END ats_dt_day
                      INTO lv_ats_day
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_ats_day   := 'WK_DAY';
                END;

                IF lv_ats_day IN ('WKND_SAT')
                THEN
                    IF ld_request_date = ld_ats_intro_date - 1
                    THEN
                        ln_ats_wknd_exists   := 1;
                    END IF;
                ELSIF lv_ats_day IN ('WKND_SUN')
                THEN
                    IF ld_request_date = ld_ats_intro_date - 2
                    THEN
                        ln_ats_wknd_exists   := 1;
                    END IF;
                ELSE
                    ln_ats_wknd_exists   := 0;
                END IF;

                -- Rule2 and 3: Customer with Buffer Days\Null in lookup
                BEGIN
                    SELECT NVL (flv.attribute2, 0)
                      INTO ln_buffer_days
                      FROM fnd_lookup_values flv
                     WHERE     flv.lookup_type =
                               'XXD_ONT_ATS_CHECK_CUSTOMERS'
                           AND flv.language = USERENV ('LANG')
                           AND enabled_flag = 'Y'
                           AND TO_NUMBER (flv.attribute1) = ln_customer_id
                           AND TRUNC (SYSDATE) BETWEEN NVL (
                                                           flv.start_date_active,
                                                           TRUNC (SYSDATE))
                                                   AND NVL (
                                                           flv.end_date_active,
                                                             TRUNC (SYSDATE)
                                                           + 1);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_buffer_days   := -1;
                END;

                /*
                            IF NVL(ln_buffer_days,0) > 0          --If customer buffer days is NOT NULL
                            THEN
                                IF (ld_request_date >= (ld_ats_intro_date - ln_buffer_days))
                                THEN
                                  ln_cust_eligible_exists := 1;
                                ELSE
                                  ln_cust_eligible_exists := 0;
                                END IF;
                            ELSIF NVL(ln_buffer_days,0) = 0       --If customer buffer days is NULL(Eligible)
                            THEN
                                ln_cust_eligible_exists := 1;
                                ln_ats_wknd_exists := 1;          --customer buffer days is NULL, Ignore ats_weekend_check
                            ELSIF  ln_buffer_days = -1      --If customer not-exists in lookup;allow orders if REQ Date after ATS Date ;don’t import the order if REQ Date is before ATS Date
                                THEN
                                IF (ld_request_date >= ld_ats_intro_date)
                                THEN
                                  ln_cust_eligible_exists := 1;
                                ELSE
                                  ln_cust_eligible_exists := 0;
                                END IF;
                            END IF;
                */
                fnd_file.put_line (fnd_file.LOG,
                                   'ats_wknd_exists :' || ln_ats_wknd_exists);
                fnd_file.put_line (fnd_file.LOG,
                                   'ln_buffer_days :' || ln_buffer_days);
                fnd_file.put_line (fnd_file.LOG,
                                   'ld_request_date :' || ld_request_date);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'ld_ats_intro_date :' || ld_ats_intro_date);

                -- fnd_file.put_line (fnd_file.LOG, 'ld_ats_intro_date - ln_buffer_days :'|| ld_ats_intro_date - ln_buffer_days);
                IF ln_ats_wknd_exists = 1
                THEN --BYPASS VALIDATION ERROR IF ATS date falls weekend (Sat or Sun) and Request Date is on Friday (1 day before)
                    fnd_file.put_line (fnd_file.LOG, 'inside condition1'); --do nothing
                ELSIF     NVL (ln_ats_wknd_exists, 0) = 0
                      AND NVL (ln_buffer_days, 0) > 0
                      AND ld_request_date >=
                          (ld_ats_intro_date - ln_buffer_days)
                THEN -- this is the case when its a weekday and customer buffer day is a non zero value
                    fnd_file.put_line (fnd_file.LOG, 'inside condition2'); --do nothing
                ELSIF (NVL (ln_ats_wknd_exists, 0) = 0 AND NVL (ln_buffer_days, 0) = 0)
                THEN                       -- no restriction for this customer
                    fnd_file.put_line (fnd_file.LOG, 'inside condition3'); --do nothing
                ELSIF     NVL (ln_ats_wknd_exists, 0) = 0
                      AND ln_buffer_days = -1
                      AND ld_request_date >= ld_ats_intro_date
                THEN
                    --If customer not-exists in lookup;allow orders if REQ Date after ATS Date ;don’t import the order if REQ Date is before ATS Date
                    fnd_file.put_line (fnd_file.LOG, 'inside condition4'); --do nothing
                ELSE
                    fnd_file.put_line (fnd_file.LOG,
                                       'inside error conditioon');

                    --------------------------------------------------------
                    -- updating the orig_sys_document_ref data to error
                    --------------------------------------------------------
                    UPDATE apps.oe_headers_iface_all
                       SET error_flag = 'Y', request_id = 0000010, last_update_date = SYSDATE,
                           last_updated_by = gn_batch_user_id
                     WHERE     orig_sys_document_ref =
                               c_cur_get_iface_data.osdr
                           AND error_flag IS NULL
                           AND request_id IS NULL;

                    ---------------------------------------------------------
                    -- updating the orig_sys_line_ref data to error
                    ---------------------------------------------------------
                    UPDATE apps.oe_lines_iface_all
                       SET error_flag = 'Y', request_id = 0000010, last_update_date = SYSDATE,
                           last_updated_by = gn_batch_user_id
                     WHERE     orig_sys_document_ref =
                               c_cur_get_iface_data.osdr
                           AND orig_sys_line_ref = c_cur_get_iface_data.oslr
                           AND error_flag IS NULL
                           AND request_id IS NULL;
                END IF;
            ELSE                                --IF ld_ats_intro_date IS NULL
                --End Added for CCR0009429
                --------------------------------------------------------
                -- updating the orig_sys_document_ref data to error
                --------------------------------------------------------
                UPDATE apps.oe_headers_iface_all
                   SET error_flag = 'Y', request_id = 0000010, last_update_date = SYSDATE,
                       last_updated_by = gn_batch_user_id
                 WHERE     orig_sys_document_ref = c_cur_get_iface_data.osdr
                       AND error_flag IS NULL
                       AND request_id IS NULL;

                ---------------------------------------------------------
                -- updating the orig_sys_line_ref data to error
                ---------------------------------------------------------
                UPDATE apps.oe_lines_iface_all
                   SET error_flag = 'Y', request_id = 0000010, last_update_date = SYSDATE,
                       last_updated_by = gn_batch_user_id
                 WHERE     orig_sys_document_ref = c_cur_get_iface_data.osdr
                       AND orig_sys_line_ref = c_cur_get_iface_data.oslr
                       AND error_flag IS NULL
                       AND request_id IS NULL;
            --Start Added for CCR0009429
            END IF;                         --IF ld_ats_intro_date IS NOT NULL

            --End Added for CCR0009429
            --------------------------------------------
            -- Committing the transacion for the update
            --------------------------------------------
            COMMIT;
            ----------------------------------
            -- Print the output for the values
            ----------------------------------
            fnd_file.put_line (fnd_file.output,
                               'PO Number :' || c_cur_get_iface_data.po);
            fnd_file.put_line (fnd_file.output,
                               'SKU :' || c_cur_get_iface_data.sku);
            fnd_file.put_line (
                fnd_file.output,
                'Intro Date :' || c_cur_get_iface_data.intro_date);
            fnd_file.put_line (
                fnd_file.output,
                'Request Date :' || c_cur_get_iface_data.request_date);
            fnd_file.put_line (
                fnd_file.output,
                '--------------------------------------------------');
        ------------------
        -- Ending the loop
        ------------------
        END LOOP;

        ------------------------
        -- End of the procedure
        ------------------------
        fnd_file.put_line (fnd_file.LOG, 'ORDER_LINE_VALIDATION End');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'MAIN Others Exception in ORDER_LINE_VALIDATION = '
                || SQLERRM);
    END order_line_validation;

    -- Start changes for CCR0008488
    FUNCTION get_sps_details (p_osid NUMBER, p_operating_unit NUMBER)
        RETURN sps_customer_tab_type
        PIPELINED
    AS
        l_sps_customer_rec   sps_customer_tab_type;
    BEGIN
        FOR l_sps_customer_rec
            IN (SELECT DISTINCT ohia.orig_sys_document_ref,
                                -- Start changes for CCR0009130
                                -- (SELECT DECODE (COUNT (1), 0, 'N', 'Y')
                                (SELECT DECODE (COUNT (1), 0, 'N', DECODE (p_osid, 6, 'Y', 'N'))
                                   -- End changes for CCR0009130
                                   FROM fnd_lookup_values flv
                                  WHERE     1 = 1
                                        AND hca.account_number =
                                            flv.lookup_code
                                        AND flv.lookup_type =
                                            'XXDO_EDI_CUSTOMERS'
                                        AND flv.language = USERENV ('LANG')
                                        AND NVL (flv.enabled_flag, 'N') = 'Y'
                                        AND NVL (flv.attribute1, 'N') = 'Y' --SPS: Y and NON-SPS: N
                                        AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                        flv.start_date_active,
                                                                        TRUNC (
                                                                            SYSDATE))
                                                                AND NVL (
                                                                        flv.end_date_active,
                                                                        TRUNC (
                                                                            SYSDATE))) sps_cust_flag
                  FROM oe_headers_iface_all ohia, hz_cust_accounts hca
                 WHERE     1 = 1
                       AND ohia.sold_to_org_id = hca.cust_account_id
                       AND ohia.error_flag IS NULL
                       AND ohia.request_id IS NULL
                       AND ohia.operation_code = 'INSERT'
                       AND ohia.order_source_id = p_osid         --Source: EDI
                       AND ohia.org_id = p_operating_unit)
        LOOP
            PIPE ROW (l_sps_customer_rec);
        END LOOP;

        RETURN;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in GET_SPS_DETAILS = ' || SQLERRM);
    END get_sps_details;

    -- End changes for CCR0008488

    --------------------------------------------------------------------
    -- Procdure to get the order type and the procedure does the below
    -- determine based on creation date and request date of an order
    -- Check the Global Attribute1 from the interface
    -- If the Global attribute1 is "BK" then the order is for bulk order
    -- Then derive the Bulk order type and Substitute here.
    --------------------------------------------------------------------
    PROCEDURE get_order_type (p_operating_unit IN NUMBER, p_osid IN NUMBER)
    IS
        ------------------------------------------------------
        -- Declaring the variables and local to the procedure
        ------------------------------------------------------
        v_ou_id           NUMBER := p_operating_unit;
        v_os_id           NUMBER := p_osid;
        v_order_type_id   NUMBER := 0;
        v_order_type      oe_transaction_types_tl.name%TYPE;
        v_request_id      NUMBER := fnd_global.conc_request_id;

        -------------------------------------------------------
        -- Cursor to get the OSDR based on the input parameters
        -------------------------------------------------------
        CURSOR cur_get_osdr IS
            SELECT ooha.customer_po_number po, ooha.orig_sys_document_ref osdr, TRUNC (ooha.request_date) request_date,
                   TRUNC (ooha.creation_date) creation_date, -----------------------------------------------------------
                                                             -- Added By Sivakumar Boothathan for the CCR : CCR0006663
                                                             -- To get the Global Attribute1
                                                             -----------------------------------------------------------
                                                             ott.name order_type, ooha.global_attribute1 bulk_identifier,
                   ott.transaction_type_id order_type_id
              ---------------------------------------------------------------------
              -- End of addition By Sivakumar Boothathan for the CCR :  CCR0006663
              ---------------------------------------------------------------------
              FROM apps.oe_headers_iface_all ooha, apps.oe_transaction_types_tl ott
             WHERE     ooha.org_id = v_ou_id
                   AND ott.transaction_type_id = ooha.order_type_id
                   AND ott.language = 'US'
                   AND ooha.order_source_id = v_os_id
                   AND ooha.error_flag IS NULL
                   AND ooha.request_id = v_request_id
                   AND ooha.operation_code = 'INSERT'
                   AND ooha.order_type_id IN
                           (SELECT TO_NUMBER (lookup_code)
                              FROM apps.oe_lookups
                             WHERE     lookup_type = 'XXDO_OM_CI_ORDER_TYPES'
                                   AND enabled_flag = 'Y'
                                   AND NVL (TRUNC (end_date_active),
                                            TRUNC (SYSDATE + 1)) >=
                                       TRUNC (SYSDATE));
    ---------------------------
    --Begining of the procedure
    ---------------------------
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'GET_ORDER_TYPE Start');

        --------------------------------------------------------
        -- Updating the request ID with the current request ID
        -- to create a subset of data
        --------------------------------------------------------
        --update apps.oe_headers_iface_all
        --set request_id with the fnd global
        -- request ID
        -------------------------------------
        BEGIN
            -- Start changes for CCR0008488
            -- PL/SQL Table get_sps_details is raising mutating error if we use this directly in the UPDATE statement
            -- Hence we have to split that and use as a FOR LOOP instead
            FOR i
                IN (SELECT *
                      FROM TABLE (get_sps_details (p_osid, p_operating_unit))
                     WHERE sps_cust_flag = 'N')
            LOOP
                -- End changes for CCR0008488
                UPDATE apps.oe_headers_iface_all ohia
                   SET request_id   = v_request_id
                 WHERE     request_id IS NULL
                       AND error_flag IS NULL
                       AND order_source_id = v_os_id
                       AND org_id = v_ou_id
                       --------------------------------------------------
                       -- Changes for CCR0006890 : EDI 860 Stuck Issue
                       --------------------------------------------------
                       AND operation_code = 'INSERT'
                       -- Start changes for CCR0008488
                       AND ohia.orig_sys_document_ref =
                           i.orig_sys_document_ref;

                -- End changes for CCR0008488

                -------------------------------------------------
                -- End of changes for CCR0006890
                -------------------------------------------------
                ---------------------------------------
                -- Updating the request ID on the lines
                -- to the fnd global request ID
                ---------------------------------------
                UPDATE apps.oe_lines_iface_all b
                   SET request_id   = v_request_id
                 WHERE     request_id IS NULL
                       AND error_flag IS NULL
                       AND order_source_id = v_os_id
                       AND org_id = v_ou_id
                       --------------------------------------------------
                       -- Changes for CCR0006890 : EDI 860 Stuck Issue
                       --------------------------------------------------
                       AND operation_code = 'INSERT'
                       --Changes added for ver CCR0007582 1.8; not to update request id for insert operations
                       -- if the insert is with header operation as "UPDATE". in other word, update request ID
                       -- only for the INSERT OPeration w.r.t to iface header
                       AND EXISTS
                               (SELECT 1
                                  FROM apps.oe_headers_iface_all a
                                 WHERE     a.orig_sys_document_ref =
                                           b.orig_sys_document_ref
                                       AND operation_code = 'INSERT'
                                       AND error_flag IS NULL)
                       -- Start changes for CCR0008488
                       AND b.orig_sys_document_ref = i.orig_sys_document_ref;
            END LOOP;
        -- End changes for CCR0008488
        -------------------------------------------------
        -- End of changes for CCR0006890
        -------------------------------------------------
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Others Error while updating the headers interface with request ID');
        END;

        fnd_file.put_line (
            fnd_file.output,
            'List Of Orders for which the Order Type Is Changed');
        fnd_file.put_line (
            fnd_file.output,
            '---------------------------------------------------');

        ------------------------------------------
        -- Beginning of the procedure to vary
        -- to get all the OSDR which matches
        -- the operating unit and order source ID
        ------------------------------------------
        FOR c_cur_get_osdr IN cur_get_osdr
        LOOP
            ---------------------------------------------------------
            -- To compare the request date and ordered date
            ---------------------------------------------------------
            BEGIN
                ----------------------------------------------------------
                -- Added By Sivakumar Boothathan For the CCR : CCR0006663
                -- on 02-OCT-2017
                ----------------------------------------------------------
                IF (c_cur_get_osdr.bulk_identifier IS NULL)
                THEN
                    SELECT ott.transaction_type_id, ott.name
                      INTO v_order_type_id, v_order_type
                      FROM apps.oe_transaction_types_tl ott, apps.fnd_lookup_values flv
                     WHERE     ott.language = 'US'
                           AND ott.transaction_type_id =
                               TO_NUMBER (flv.attribute7)
                           AND flv.lookup_type = 'XXDO_OM_SEASON_CODES'
                           AND flv.language = 'US'
                           AND flv.enabled_flag = 'Y'
                           ------------------------------------------------
                           -- Adding a new code for the CCR : CCR0006663
                           ------------------------------------------------
                           AND flv.tag IS NULL
                           AND TO_NUMBER (flv.attribute8) =
                               c_cur_get_osdr.order_type_id
                           ------------------------------------------------
                           -- End of code addition for CCR : CCR0006663
                           ------------------------------------------------
                           AND TO_NUMBER (flv.attribute5) = v_ou_id
                           AND NVL (TRUNC (flv.end_date_active),
                                    TRUNC (SYSDATE + 1)) >=
                               TRUNC (SYSDATE)
                           AND c_cur_get_osdr.creation_date >=
                               TRUNC (
                                   TO_DATE (flv.attribute1,
                                            'RRRR/MM/DD HH24:MI:SS'))
                           AND c_cur_get_osdr.creation_date <=
                               TRUNC (
                                   TO_DATE (flv.attribute2,
                                            'RRRR/MM/DD HH24:MI:SS'))
                           AND c_cur_get_osdr.request_date >=
                               TRUNC (
                                   TO_DATE (flv.attribute3,
                                            'RRRR/MM/DD HH24:MI:SS'))
                           AND c_cur_get_osdr.request_date <=
                               TRUNC (
                                   TO_DATE (flv.attribute4,
                                            'RRRR/MM/DD HH24:MI:SS'));
                ----------------------------------------------------------
                -- Added By Sivakumar Boothathan For the CCR : CCR0006663
                -- on 02-OCT-2017
                ----------------------------------------------------------
                ELSIF (c_cur_get_osdr.bulk_identifier = 'BK')
                THEN
                    BEGIN
                        SELECT ott.transaction_type_id, ott.name
                          INTO v_order_type_id, v_order_type
                          FROM apps.oe_transaction_types_tl ott, apps.fnd_lookup_values flv
                         WHERE     ott.language = 'US'
                               AND ott.transaction_type_id =
                                   TO_NUMBER (flv.attribute7)
                               AND flv.lookup_type = 'XXDO_OM_SEASON_CODES'
                               AND flv.language = 'US'
                               AND flv.enabled_flag = 'Y'
                               AND flv.tag = 'BLK'
                               AND TO_NUMBER (flv.attribute8) =
                                   c_cur_get_osdr.order_type_id
                               AND TO_NUMBER (flv.attribute5) = v_ou_id
                               AND NVL (TRUNC (flv.end_date_active),
                                        TRUNC (SYSDATE + 1)) >=
                                   TRUNC (SYSDATE)
                               AND c_cur_get_osdr.creation_date >=
                                   TRUNC (
                                       TO_DATE (flv.attribute1,
                                                'RRRR/MM/DD HH24:MI:SS'))
                               AND c_cur_get_osdr.creation_date <=
                                   TRUNC (
                                       TO_DATE (flv.attribute2,
                                                'RRRR/MM/DD HH24:MI:SS'))
                               AND TRUNC ((c_cur_get_osdr.request_date),
                                          'month') >=
                                   TRUNC (
                                       TO_DATE (flv.attribute3,
                                                'RRRR/MM/DD HH24:MI:SS'))
                               AND TRUNC ((c_cur_get_osdr.request_date),
                                          'month') <=
                                   TRUNC (
                                       TO_DATE (flv.attribute4,
                                                'RRRR/MM/DD HH24:MI:SS'));
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Exception During Bulk Order Type Derivation');

                            UPDATE apps.oe_headers_iface_all
                               SET request_id = 0000020, error_flag = 'Y', last_update_date = SYSDATE,
                                   last_updated_by = gn_batch_user_id
                             WHERE     orig_sys_document_ref =
                                       c_cur_get_osdr.osdr
                                   AND operation_code = 'INSERT'
                                   AND error_flag IS NULL
                                   AND request_id = v_request_id;
                    END;

                    ------------------------------------------------------------
                    -- Overwrite the request date to the 1st date of the month
                    -- Latest schedule limit as difference between First day of
                    -- the month and the last day of the month
                    ------------------------------------------------------------
                    BEGIN
                        fnd_file.put_line (fnd_file.LOG,
                                           'OSDR:' || c_cur_get_osdr.osdr);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'GA1:' || c_cur_get_osdr.bulk_identifier);

                        UPDATE apps.oe_headers_iface_all
                           SET global_attribute1   = NULL
                         WHERE     orig_sys_document_ref =
                                   c_cur_get_osdr.osdr
                               AND operation_code = 'INSERT'
                               AND global_attribute1 = 'BK'
                               AND error_flag IS NULL
                               AND request_id = v_request_id;

                        fnd_file.put_line (fnd_file.LOG,
                                           'OSDRL:' || c_cur_get_osdr.osdr);

                        fnd_file.put_line (fnd_file.LOG, 'END OF UPDATE');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error While overwriting the request date and Latest schedule limit');
                    END;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Others Error In the Main cursor of the order type derivation');
                    fnd_file.put_line (fnd_file.LOG, SQLCODE);
                    fnd_file.put_line (fnd_file.LOG, SQLERRM);

                    UPDATE apps.oe_headers_iface_all
                       SET request_id = 0000020, error_flag = 'Y', last_update_date = SYSDATE,
                           last_updated_by = gn_batch_user_id
                     WHERE     orig_sys_document_ref = c_cur_get_osdr.osdr
                           AND operation_code = 'INSERT'
                           AND error_flag IS NULL
                           AND request_id = v_request_id;
            END;

            -----------------------------------------
            -- Updating the order type ID to the OSDR
            -- adding the change sequence as 1
            -----------------------------------------
            BEGIN
                UPDATE apps.oe_headers_iface_all
                   SET order_type_id = v_order_type_id, last_update_date = SYSDATE, last_updated_by = gn_batch_user_id,
                       change_sequence = 1, force_apply_flag = 'Y', request_id = NULL
                 WHERE     orig_sys_document_ref = c_cur_get_osdr.osdr
                       AND operation_code = 'INSERT'
                       AND error_flag IS NULL
                       AND request_id = v_request_id;

                UPDATE apps.oe_lines_iface_all
                   SET last_update_date = SYSDATE, last_updated_by = gn_batch_user_id, change_sequence = 1,
                       request_id = NULL
                 WHERE     orig_sys_document_ref = c_cur_get_osdr.osdr
                       AND operation_code = 'INSERT'
                       AND error_flag IS NULL
                       AND request_id = v_request_id
                       -------------------------------------------------------------------------------
                       ---  Changes added for ver CCR0007582 1.8 : Header iface table updating the request id
                       ---  to null, so have to update lines iface table first using exists condition
                       ---  to check if header record exists for that particular header/request id.
                       -------------------------------------------------------------------------------
                       AND EXISTS
                               (SELECT 1
                                  FROM apps.oe_headers_iface_all
                                 WHERE     orig_sys_document_ref =
                                           c_cur_get_osdr.osdr
                                       AND operation_code = 'INSERT'
                                       AND error_flag IS NULL);

                --------------------------------------------
                -- Committing the transacion for the update
                --------------------------------------------
                COMMIT;
                -------------------
                -- Print The Output
                -------------------
                fnd_file.put_line (
                    fnd_file.output,
                    'Customer PO Number :' || c_cur_get_osdr.po);
                fnd_file.put_line (
                    fnd_file.output,
                    'Orig_Sys_Document_Ref :' || c_cur_get_osdr.osdr);
                fnd_file.put_line (
                    fnd_file.output,
                    'Order Ordered Date :' || c_cur_get_osdr.creation_date);
                fnd_file.put_line (
                    fnd_file.output,
                    'Order Request Date :' || c_cur_get_osdr.request_date);
                fnd_file.put_line (fnd_file.output,
                                   'Changed Order Type :' || v_order_type);
                fnd_file.put_line (fnd_file.output, 'Change Sequence : 1');
                fnd_file.put_line (
                    fnd_file.output,
                    '----------------------------------------------------');
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;

        BEGIN
            UPDATE apps.oe_headers_iface_all ohia
               SET last_update_date = SYSDATE, last_updated_by = gn_batch_user_id, change_sequence = 1,
                   force_apply_flag = 'Y', request_id = NULL
             WHERE     order_type_id NOT IN
                           (SELECT TO_NUMBER (lookup_code)
                              FROM apps.oe_lookups
                             WHERE     lookup_type = 'XXDO_OM_CI_ORDER_TYPES'
                                   AND enabled_flag = 'Y'
                                   AND NVL (TRUNC (end_date_active),
                                            TRUNC (SYSDATE + 1)) >=
                                       TRUNC (SYSDATE))
                   AND org_id = v_ou_id
                   AND order_source_id = v_os_id
                   AND error_flag IS NULL
                   AND request_id = v_request_id;

            UPDATE apps.oe_lines_iface_all olia
               SET last_update_date = SYSDATE, last_updated_by = gn_batch_user_id, change_sequence = 1,
                   request_id = NULL
             WHERE     orig_sys_document_ref IN
                           (SELECT orig_sys_document_ref
                              FROM apps.oe_headers_iface_all
                             WHERE     request_id IS NULL
                                   AND error_flag IS NULL
                                   AND org_id = v_ou_id
                                   AND order_source_id = v_os_id
                                   AND order_type_id NOT IN
                                           (SELECT TO_NUMBER (lookup_code)
                                              FROM apps.oe_lookups
                                             WHERE     lookup_type =
                                                       'XXDO_OM_CI_ORDER_TYPES'
                                                   AND enabled_flag = 'Y'
                                                   AND NVL (
                                                           TRUNC (
                                                               end_date_active),
                                                           TRUNC (
                                                               SYSDATE + 1)) >=
                                                       TRUNC (SYSDATE)))
                   AND org_id = v_ou_id
                   AND order_source_id = v_os_id
                   AND error_flag IS NULL
                   AND request_id = v_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error While Updating the change sequence to 1 for non wholesale order types');
        END;

        fnd_file.put_line (fnd_file.LOG, 'GET_ORDER_TYPE End');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in GET_ORDER_TYPE = ' || SQLERRM);
    END get_order_type;

    --------------------------------------------------------------------
    -- Procdure to validate for any EDI : 860 i.e updates by an
    -- EDI order and don't process an EDI order if there is a reservation exists
    --------------------------------------------------------------------

    PROCEDURE edi_860_validation (p_operating_unit   IN NUMBER,
                                  p_osid             IN NUMBER)
    IS
        ------------------------------------------------------
        -- Declaring the variables and local to the procedure
        ------------------------------------------------------
        v_ou_id                  NUMBER := p_operating_unit;
        v_os_id                  NUMBER := p_osid;
        v_order_type_id          NUMBER := 0;
        v_order_type             oe_transaction_types_tl.name%TYPE;
        ln_hold_id               NUMBER;                       --added for 2.8
        lv_release_reason_code   VARCHAR2 (1000);              --added for 2.8
        lv_release_comment       VARCHAR2 (1000);              --added for 2.8


        -------------------------------------------------------
        -- Cursor to get the OSDR based on the input parameters
        -------------------------------------------------------
        CURSOR cur_get_osdr IS
            SELECT DISTINCT ooh.customer_po_number po, ooh.orig_sys_document_ref osdr, TRUNC (ooh.request_date) request_date,
                            TRUNC (ooh.creation_date) creation_date
              FROM apps.oe_headers_iface_all ooh, apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola
             WHERE     ooh.org_id = v_ou_id
                   AND ooh.order_source_id = v_os_id
                   AND ooh.error_flag IS NULL
                   AND ooh.request_id IS NULL
                   AND ooh.operation_code = 'UPDATE'
                   AND ooh.orig_sys_document_ref = ooha.orig_sys_document_ref
                   AND ooha.header_id = oola.header_id
                   AND oola.line_category_code = 'ORDER'
                   AND oola.open_flag = 'Y'
                   --------------------------------------------------------------------
                   -- Changes to allow order extensions with or without reservation
                   -- Added By Sivakumar Boothathan on 01/05/2018
                   --------------------------------------------------------------------
                   AND NVL (fnd_date.canonical_to_date (ooh.attribute1),
                            TO_DATE ('01-JAN-1900')) =
                       NVL (fnd_date.canonical_to_date (ooha.attribute1),
                            TO_DATE ('01-JAN-1900'))
                   --------------------------------------------------------------------------
                   -- Changes to allow Order extensions with or without reservation
                   -- Added By Sivakumar Boothathan on 01/05/2018
                   --------------------------------------------------------------------------
                   AND EXISTS
                           (SELECT 1
                              FROM apps.mtl_reservations
                             WHERE     demand_source_line_id = oola.line_id
                                   AND organization_id =
                                       oola.ship_from_org_id);

        -------------------------------------------------------
        -- Cursor to get the OSDR based on the input parameters
        -------------------------------------------------------
        CURSOR cur_get_osdr_nor IS
            SELECT DISTINCT ooh.customer_po_number po, ooh.orig_sys_document_ref osdr, ooha.order_type_id order_type_id
              FROM apps.oe_headers_iface_all ooh, apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola
             WHERE     ooh.org_id = v_ou_id
                   AND ooh.order_source_id = v_os_id
                   AND ooh.error_flag IS NULL
                   AND ooh.request_id IS NULL
                   AND ooh.operation_code = 'UPDATE'
                   AND ooh.orig_sys_document_ref = ooha.orig_sys_document_ref
                   AND ooha.header_id = oola.header_id
                   AND oola.line_category_code = 'ORDER'
                   AND oola.open_flag = 'Y'
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.mtl_reservations
                             WHERE     demand_source_line_id = oola.line_id
                                   AND organization_id =
                                       oola.ship_from_org_id)
                   -----------------------------------------------------------
                   -- Added By Sivakumar Boothathan for CCR :CCR0006663
                   --To ignore the bulk orders
                   -----------------------------------------------------------
                   AND ooha.global_attribute1 IS NULL
            -----------------------------------------------------------
            -- End of changes By Siva Boothathan for CCR :CCR0006663
            --To ignore the bulk orders
            -----------------------------------------------------------
            ------------------------------------------------
            -- Added By Sivakumar Boothathan on 05-JAN-2018
            -- To Allow extensions i.e cancel date update
            -- With Reservations
            ------------------------------------------------
            UNION ALL
            SELECT DISTINCT ooh.customer_po_number po, ooh.orig_sys_document_ref osdr, ooha.order_type_id order_type_id
              FROM apps.oe_headers_iface_all ooh, apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola
             WHERE     ooh.org_id = v_ou_id
                   AND ooh.order_source_id = v_os_id
                   AND ooh.error_flag IS NULL
                   AND ooh.request_id IS NULL
                   AND ooh.operation_code = 'UPDATE'
                   AND ooh.orig_sys_document_ref = ooha.orig_sys_document_ref
                   AND ooha.header_id = oola.header_id
                   AND oola.line_category_code = 'ORDER'
                   AND oola.open_flag = 'Y'
                   AND ooha.global_attribute1 IS NULL
                   AND NVL (fnd_date.canonical_to_date (ooh.attribute1),
                            TO_DATE ('01-JAN-1900')) <>
                       NVL (fnd_date.canonical_to_date (ooha.attribute1),
                            TO_DATE ('01-JAN-1900'))
                   AND EXISTS
                           (SELECT 1
                              FROM apps.mtl_reservations
                             WHERE     demand_source_line_id = oola.line_id
                                   AND organization_id =
                                       oola.ship_from_org_id);
    ---------------------------
    --Begining of the procedure
    ---------------------------
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'EDI_860_VALIDATION Start');
        fnd_file.put_line (
            fnd_file.output,
            'List Of Orders which failed updates as it is already dropped to DC');
        fnd_file.put_line (
            fnd_file.output,
            '--------------------------------------------------------------------');

        -------------------------------------------
        -- Beginning of the procedure to vary
        -- to get all the OSDR which matches
        -- the operating unit and order source ID
        ------------------------------------------
        FOR c_cur_get_osdr IN cur_get_osdr
        LOOP
            ---------------------------------------------------------
            -- To compare the request date and ordered date
            ---------------------------------------------------------

            BEGIN
                UPDATE apps.oe_headers_iface_all
                   SET error_flag = 'Y', request_id = 0000030, last_update_date = SYSDATE,
                       last_updated_by = gn_batch_user_id
                 WHERE     orig_sys_document_ref = c_cur_get_osdr.osdr
                       AND error_flag IS NULL
                       AND request_id IS NULL;

                --------------------------------------------
                -- Committing the transacion for the update
                --------------------------------------------
                COMMIT;
                -------------------
                -- Print The Output
                -------------------
                fnd_file.put_line (
                    fnd_file.output,
                    'Customer PO Number :' || c_cur_get_osdr.po);
                fnd_file.put_line (
                    fnd_file.output,
                    'Orig_Sys_Document_Ref :' || c_cur_get_osdr.osdr);
                fnd_file.put_line (
                    fnd_file.output,
                    'Order Ordered Date :' || c_cur_get_osdr.creation_date);
                fnd_file.put_line (
                    fnd_file.output,
                    'Order Request Date :' || c_cur_get_osdr.request_date);
                fnd_file.put_line (
                    fnd_file.output,
                    '----------------------------------------------------');
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;

        FOR c_cur_get_osdr_nor IN cur_get_osdr_nor
        LOOP
            ---------------------------------------------------------
            -- To compare the request date and ordered date
            ---------------------------------------------------------
            BEGIN
                UPDATE apps.oe_headers_iface_all
                   SET order_type_id = c_cur_get_osdr_nor.order_type_id, last_update_date = SYSDATE, last_updated_by = gn_batch_user_id
                 WHERE     orig_sys_document_ref = c_cur_get_osdr_nor.osdr
                       AND error_flag IS NULL
                       AND request_id IS NULL;

                --------------------------------------------
                -- Committing the transacion for the update
                --------------------------------------------
                COMMIT;
                -------------------
                -- Print The Output
                -------------------
                fnd_file.put_line (
                    fnd_file.output,
                    '----------------------------------------------------');
                fnd_file.put_line (
                    fnd_file.output,
                    'Order Type Changes For the Below Update Orders:');
                fnd_file.put_line (
                    fnd_file.output,
                    'Customer PO Number :' || c_cur_get_osdr_nor.po);
                fnd_file.put_line (
                    fnd_file.output,
                    'Orig_Sys_Document_Ref :' || c_cur_get_osdr_nor.osdr);
                fnd_file.put_line (
                    fnd_file.output,
                    'Order Type ID :' || c_cur_get_osdr_nor.order_type_id);
                fnd_file.put_line (
                    fnd_file.output,
                    '----------------------------------------------------');
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;


        fnd_file.put_line (fnd_file.LOG, 'EDI_860_VALIDATION End');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'MAIN Others Exception in EDI_860_VALIDATION = ' || SQLERRM);
    END edi_860_validation;

    -------------------------------------------------------------
    -- Procedure to check for sales order duplicate
    -- And error out if the sales is duplicate for
    -- Customer PO Number, Operation Code, Customer Number
    -------------------------------------------------------------

    PROCEDURE order_header_duplicate (p_operating_unit   IN NUMBER,
                                      p_osid             IN NUMBER)
    IS
        ------------------------------------------------------
        -- Declaring the variables and local to the procedure
        ------------------------------------------------------
        v_ou_id                NUMBER := p_operating_unit;
        v_os_id                NUMBER := p_osid;
        v_customer_po_number   VARCHAR2 (50) := NULL;
        v_sold_to_org_id       NUMBER;
        v_change_sequence      VARCHAR2 (50) := NULL;
        v_duplicate_check      NUMBER := 0;

        CURSOR cursor_dup_po_check                   --start w.r.t Version 1.6
                                   IS
              SELECT customer_po_number, sold_to_org_id, change_sequence,
                     operation_code, COUNT (1)
                FROM apps.oe_headers_iface_all
               WHERE     error_flag IS NULL
                     AND request_id IS NULL
                     AND org_id = v_ou_id
                     AND order_source_id NOT IN
                             (SELECT order_source_id
                                FROM                       --w.r.t version 1.4
                                     fnd_lookup_values_vl flv, oe_order_sources os
                               WHERE     meaning = name
                                     AND lookup_type =
                                         'XXD_PREVAL_EXCL_DUP_CHK'
                                     AND flv.enabled_flag = 'Y')
                     AND order_source_id = v_os_id
            GROUP BY customer_po_number, sold_to_org_id, operation_code,
                     change_sequence
              HAVING COUNT (1) > 1;
    ------------------------------------------------------
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'ORDER_HEADER_DUPLICATE Start');

        FOR rec_dup_po_check IN cursor_dup_po_check
        LOOP                                           --End w.r.t Version 1.6
            BEGIN
                /*
                SELECT customer_po_number,
                sold_to_org_id,
                change_sequence,
                COUNT (1)
                INTO v_customer_po_number,
                v_sold_to_org_id,
                v_change_sequence,
                v_duplicate_check
                FROM apps.oe_headers_iface_all
                WHERE     error_flag IS NULL
                AND request_id IS NULL
                AND org_id = v_ou_id
                AND order_source_id NOT IN
                (SELECT order_source_id
                FROM                           --w.r.t version 1.4
                fnd_lookup_values_vl flv, oe_order_sources os
                WHERE     meaning = name
                AND lookup_type = 'XXD_PREVAL_EXCL_DUP_CHK'
                AND flv.enabled_flag = 'Y')
                AND order_source_id = v_os_id
                GROUP BY customer_po_number,
                sold_to_org_id,
                operation_code,
                change_sequence
                HAVING COUNT (1) > 1;*/
                UPDATE oe_headers_iface_all
                   SET error_flag = 'Y', request_id = 40
                 WHERE     customer_po_number =
                           rec_dup_po_check.customer_po_number
                       AND sold_to_org_id = rec_dup_po_check.sold_to_org_id
                       AND operation_code = rec_dup_po_check.operation_code
                       AND NVL (change_sequence, -99) =
                           NVL (rec_dup_po_check.change_sequence, -99);

                COMMIT;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    fnd_file.put_line (fnd_file.LOG, 'No Duplicates found');
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Others Exception in duplicate check = ' || SQLERRM);
            END;
        END LOOP;

        fnd_file.put_line (fnd_file.LOG, 'ORDER_HEADER_DUPLICATE End');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'MAIN Others Exception in ORDER_HEADER_DUPLICATE = '
                || SQLERRM);
    END order_header_duplicate;

    --1.6 Start : Added by Infosys for CCR0007225

    PROCEDURE cancel_date_validation (p_operating_unit   IN NUMBER,
                                      p_osid             IN NUMBER)
    IS
        -----------------------------------
        -- Declaring Local variables
        -- visible inside the procedure
        -----------------------------------
        v_ou_id      NUMBER := p_operating_unit;
        v_os_id      NUMBER := p_osid;
        v_result     NUMBER := 0;
        l_date       DATE := NULL;
        l_date1      DATE := NULL;
        l_hdr_vas    VARCHAR2 (240);                                -- ver 2.3
        l_line_vas   VARCHAR2 (240);                                -- ver 2.3

        -----------------------------------
        -- Added for ver 1.9
        -- Cursor to fetch lines to validate cancel date > request date
        -----------------------------------
        CURSOR cur_get_iface_lines (v_ou_id   IN NUMBER,
                                    v_os_id   IN NUMBER,
                                    v_osdr    IN VARCHAR2)
        IS
            SELECT /*+ parallel(2) */
                   TRUNC (oola.request_date) line_request_date, TRUNC (ooha.request_date) hdr_request_date, oola.attribute1 line_cancel_date,
                   ooha.attribute1 hdr_cancel_date, oola.ORIG_SYS_DOCUMENT_REF, oola.ORIG_SYS_LINE_REF,
                   oola.sold_to_org_id,                             -- ver 2.3
                                        oola.ship_to_org_id,        -- ver 2.3
                                                             inventory_item_id -- ver 2.3
              FROM apps.oe_headers_iface_all ooha, apps.oe_lines_iface_all oola
             WHERE     ooha.orig_sys_document_ref =
                       oola.orig_sys_document_ref
                   AND ooha.org_id = oola.org_id
                   AND ooha.request_id IS NULL
                   AND ooha.error_flag IS NULL
                   AND ooha.org_id = v_ou_id
                   AND ooha.order_source_id = v_os_id
                   AND ooha.orig_sys_document_ref = v_osdr;

        -----------------------------------------------------------------------------
        -- Cursor to get the list of order headers and lines in the interface table
        -----------------------------------------------------------------------------
        CURSOR cur_get_iface_data (v_ou_id IN NUMBER, v_os_id IN NUMBER)
        IS
            SELECT /*+ parallel(2) */
                   ooha.customer_po_number po, ooha.orig_sys_document_ref osdr, ooha.attribute1 cancel_date,
                   TRUNC (ooha.request_date) request_date, -- Used for ver 1.9
                                                           sold_to_org_id, ship_to_org_id
              FROM apps.oe_headers_iface_all ooha
             WHERE     1 = 1
                   AND ooha.request_id IS NULL
                   AND ooha.error_flag IS NULL --  AND ooha.operation_code          = 'UPDATE'
                   AND ooha.org_id = v_ou_id
                   AND ooha.order_source_id = v_os_id;
    ----------------------------------------------------------
    -- Beginning of the procedure and the function here is to
    -- mark the records from the cursor as error_flag = 'Y'
    -- and request id as 0000000 so that the user knows the
    -- reason for the error line which is the item failed
    ---------------------------------------------------------
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'CANCEL_DATE_VALIDATION Start');
        fnd_file.put_line (
            fnd_file.output,
            'List Of Order Lines before cancel date validation');
        fnd_file.put_line (
            fnd_file.output,
            '---------------------------------------------------');

        --------------------------------------------------
        -- Start looping the cursor : cur_get_iface_data
        --------------------------------------------------
        FOR c_cur_get_iface_data IN cur_get_iface_data (v_ou_id, v_os_id)
        LOOP
            BEGIN
                v_result    := 0;

                BEGIN
                    SELECT TO_DATE ('2016/01/01', 'YYYY/MM/DD HH24:MI:SS')
                      INTO l_date1
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'TO DATE conversion failed for 2016/01/01.');
                END;

                fnd_file.put_line (fnd_file.output, 'l_date : ' || l_date);
                fnd_file.put_line (fnd_file.output, 'l_date1 : ' || l_date1);
                fnd_file.put_line (
                    fnd_file.output,
                    'Before Orig_sys_document_ref : ' || c_cur_get_iface_data.osdr);
                fnd_file.put_line (fnd_file.output,
                                   'Before V_result: ' || v_result);
                fnd_file.put_line (
                    fnd_file.output,
                    'Before cancel_date: ' || c_cur_get_iface_data.cancel_date);

                IF c_cur_get_iface_data.cancel_date IS NULL -- START Added as part of CCR0010488
                THEN
                    v_result   := 0;
                ELSE                        -- END Added as part of CCR0010488
                    v_result   :=
                        xxd_isdate (c_cur_get_iface_data.cancel_date,
                                    'YYYY/MM/DD HH24:MI:SS');
                    fnd_file.put_line (fnd_file.output,
                                       'After  V_result: ' || v_result);
                END IF;                         -- Added as part of CCR0010488

                IF v_result = 1
                THEN
                    BEGIN
                        l_date   :=
                            TO_DATE (c_cur_get_iface_data.cancel_date,
                                     'YYYY/MM/DD HH24:MI:SS');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'TO DATE conversion failed for : '
                                || c_cur_get_iface_data.cancel_date);
                    END;
                END IF;

                --Begin ver 2.3 calling function to get header level vas for EDI and hubsoft orders
                l_hdr_vas   := NULL;
                l_hdr_vas   :=
                    get_vas_code ('HEADER', c_cur_get_iface_data.sold_to_org_id, c_cur_get_iface_data.ship_to_org_id
                                  , NULL);

                UPDATE apps.oe_headers_iface_all
                   SET attribute14   = l_hdr_vas
                 WHERE     orig_sys_document_ref = c_cur_get_iface_data.osdr
                       AND error_flag IS NULL
                       AND request_id IS NULL;


                --End  ver 2.3 calling function to get header level vas for EDI and hubsoft orders

                --
                --         fnd_file.put_line (
                --         fnd_file.output,'Cancel date check:  '|| to_date(c_cur_get_iface_data.cancel_date,'YYYY/MM/DD HH24:MI:SS'));
                IF (v_result != 1)
                THEN
                    fnd_file.put_line (
                        fnd_file.output,
                        'Inside IF, updating request ID to 50 due to incorrect date format.');

                    --------------------------------------------------------
                    -- updating the orig_sys_document_ref data to error
                    --------------------------------------------------------
                    BEGIN
                        UPDATE apps.oe_headers_iface_all
                           SET error_flag = 'Y', request_id = 0000050, last_update_date = SYSDATE,
                               last_updated_by = gn_batch_user_id
                         WHERE     orig_sys_document_ref =
                                   c_cur_get_iface_data.osdr
                               AND error_flag IS NULL
                               AND request_id IS NULL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Update failed while marking the OSDR as Error in IF : '
                                || c_cur_get_iface_data.osdr);
                    END;

                    ---------------------------------------------------------
                    -- updating the orig_sys_line_ref data to error
                    ---------------------------------------------------------
                    BEGIN
                        UPDATE apps.oe_lines_iface_all
                           SET error_flag = 'Y', request_id = 0000050, last_update_date = SYSDATE,
                               last_updated_by = gn_batch_user_id
                         WHERE     orig_sys_document_ref =
                                   c_cur_get_iface_data.osdr
                               AND error_flag IS NULL
                               AND request_id IS NULL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Update failed while marking the OSDR and OSLR as Error in IF : '
                                || c_cur_get_iface_data.osdr);
                    END;

                    --------------------------------------------
                    -- Committing the transaction for the update
                    --------------------------------------------
                    COMMIT;
                --------------------------------------------------------
                -- Begin: ver 1.9 Block to validate request and cancel date at header level
                --------------------------------------------------------
                --  ELSIF (l_date < l_date1)  --  commented for ver 1.9
                ELSIF TRUNC (l_date) <= c_cur_get_iface_data.request_date -- VER 1.9 generic validation for cancel date is less than or equal to request date (time stamp ignored)
                THEN
                    fnd_file.put_line (
                        fnd_file.output,
                        'Inside ELSIF, updating request ID to 60 as cancel date is less than the request date');


                    --------------------------------------------------------
                    -- updating the orig_sys_document_ref data to error
                    --------------------------------------------------------
                    BEGIN
                        UPDATE apps.oe_headers_iface_all
                           SET error_flag = 'Y', request_id = 0000060, -- ver 1.9
                                                                       last_update_date = SYSDATE,
                               last_updated_by = gn_batch_user_id
                         WHERE     orig_sys_document_ref =
                                   c_cur_get_iface_data.osdr
                               AND error_flag IS NULL
                               AND request_id IS NULL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Update failed while marking the OSDR as Error in ELSIF : '
                                || c_cur_get_iface_data.osdr);
                    END;

                    ---------------------------------------------------------
                    -- updating the orig_sys_line_ref data to error
                    ---------------------------------------------------------
                    BEGIN
                        UPDATE apps.oe_lines_iface_all
                           SET error_flag = 'Y', request_id = 0000060, -- ver 1.9
                                                                       last_update_date = SYSDATE,
                               last_updated_by = gn_batch_user_id
                         WHERE     orig_sys_document_ref =
                                   c_cur_get_iface_data.osdr
                               AND error_flag IS NULL
                               AND request_id IS NULL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Update failed while marking the OSDR and OSLR as Error in ELSIF : '
                                || c_cur_get_iface_data.osdr);
                    END;

                    --------------------------------------------
                    -- Committing the transaction for the update
                    --------------------------------------------
                    COMMIT;
                ELSE
                    fnd_file.put_line (
                        fnd_file.output,
                           'Cancel date is correct for the Orig sys document ref : '
                        || c_cur_get_iface_data.osdr);
                END IF;
            END;

            ----------------------------------
            -- Print the output for the values
            ----------------------------------
            fnd_file.put_line (
                fnd_file.output,
                'Orig sys document ref :' || c_cur_get_iface_data.osdr);
            fnd_file.put_line (
                fnd_file.output,
                '--------------------------------------------------');

            --------------------------------------------------------
            -- Begin: Ver 13.0 Block to validate request and cancel date at line level for the current Header
            --------------------------------------------------------
            FOR c_cur_get_iface_line
                IN cur_get_iface_lines (v_ou_id,
                                        v_os_id,
                                        c_cur_get_iface_data.osdr)
            LOOP
                --Begin ver 2.3 calling function to get header level vas for EDI and hubsoft orders
                l_line_vas   := NULL;
                l_line_vas   :=
                    get_vas_code ('LINE', c_cur_get_iface_line.sold_to_org_id, c_cur_get_iface_line.ship_to_org_id
                                  , c_cur_get_iface_line.inventory_item_id);

                UPDATE apps.oe_lines_iface_all
                   SET attribute14   = l_line_vas
                 WHERE     ORIG_SYS_DOCUMENT_REF =
                           c_cur_get_iface_line.ORIG_SYS_DOCUMENT_REF --CCR0009335
                       AND ORIG_SYS_LINE_REF =
                           c_cur_get_iface_line.ORIG_SYS_LINE_REF
                       AND error_flag IS NULL
                       AND request_id IS NULL;

                --End  ver 2.3 calling function to get header level vas for EDI and hubsoft orders
                fnd_file.put_line (
                    fnd_file.LOG,
                    'c_cur_get_iface_data.osdr.' || c_cur_get_iface_data.osdr);
                fnd_file.put_line (
                    fnd_file.LOG,
                       'c_cur_get_iface_line.line_cancel_date.'
                    || TO_DATE (c_cur_get_iface_line.line_cancel_date,
                                'YYYY/MM/DD'));
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Hder cancel date l_date.' || TRUNC (l_date));
                fnd_file.put_line (
                    fnd_file.LOG,
                       'c_cur_get_iface_line.line_request_date.'
                    || c_cur_get_iface_line.line_request_date);
                fnd_file.put_line (
                    fnd_file.LOG,
                       'c_cur_get_iface_data.hdr_request_date.'
                    || c_cur_get_iface_line.hdr_request_date);

                IF NVL (
                       TO_DATE (c_cur_get_iface_line.line_cancel_date,
                                'YYYY/MM/DD'),
                       TRUNC (l_date)) <=
                   NVL (c_cur_get_iface_line.line_request_date,
                        c_cur_get_iface_line.hdr_request_date)
                THEN
                    fnd_file.put_line (
                        fnd_file.output,
                           'Inside IF, updating request ID to 60 due to cancel date < Request date for the given line orig_sys_line_ref.'
                        || c_cur_get_iface_line.ORIG_SYS_LINE_REF);

                    --------------------------------------------------------
                    -- updating the orig_sys_document_ref data to error
                    --------------------------------------------------------
                    BEGIN
                        UPDATE apps.oe_headers_iface_all
                           SET error_flag = 'Y', request_id = 0000060, last_update_date = SYSDATE,
                               last_updated_by = gn_batch_user_id
                         WHERE     orig_sys_document_ref =
                                   c_cur_get_iface_data.osdr
                               AND error_flag IS NULL
                               AND request_id IS NULL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Update failed on hdr iface table at line loop inside Header loop while marking the OSDR as Error in IF : '
                                || c_cur_get_iface_data.osdr);
                    END;

                    ---------------------------------------------------------
                    -- updating the orig_sys_line_ref data to error
                    ---------------------------------------------------------
                    BEGIN
                        UPDATE apps.oe_lines_iface_all
                           SET error_flag = 'Y', request_id = 0000060, last_update_date = SYSDATE,
                               last_updated_by = gn_batch_user_id
                         WHERE     orig_sys_document_ref =
                                   c_cur_get_iface_data.osdr
                               AND error_flag IS NULL
                               AND request_id IS NULL;

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'No of Rows updated.' || SQL%ROWCOUNT);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Update failed on lines iface table at line loop inside Header loop while marking the OSDR as Error in IF : '
                                || c_cur_get_iface_data.osdr);
                    END;

                    --------------------------------------------
                    -- Committing the transaction for the update
                    --------------------------------------------
                    COMMIT;
                    EXIT; -- ONE TIME ENTRY INTO THIS FOR LOOP AND REACHING AT THIS POINT IS GOOD ENOUGH TO MARK THE COMPLETE OSDR AS INVALID. NO FURTHER LOOPING IS REQUIRED
                END IF;
            END LOOP;                                         -- END LINE LOOP
        --------------------------------------------------
        -- End Changes for Ver 1.9
        --------------------------------------------------

        ------------------
        -- Ending the loop
        ------------------
        END LOOP;                                           -- end header loop

        ------------------------
        -- End of the procedure
        ------------------------
        fnd_file.put_line (fnd_file.LOG, 'CANCEL_DATE_VALIDATION End');
    EXCEPTION
        WHEN OTHERS
        THEN
            --  NULL;
            fnd_file.put_line (
                fnd_file.LOG,
                'SQLCODE : ' || SQLCODE || '. ERROR Message : ' || SQLERRM);
    END cancel_date_validation;

    -- Start Added for CCR0009954 -----
    PROCEDURE generate_report_prc (pv_request_id NUMBER)
    IS
        lv_output_file      UTL_FILE.file_type;
        lv_outbound_file    VARCHAR2 (4000);
        lv_err_msg          VARCHAR2 (4000) := NULL;
        lv_directory_path   VARCHAR2 (1000);
        lv_line             VARCHAR2 (32767) := NULL;
        lv_message          VARCHAR2 (32000);
        lv_mail_delimiter   VARCHAR2 (1) := '/';
        lv_exc_file_name    VARCHAR2 (1000);
        lv_result           VARCHAR2 (100);
        l_file_seq          NUMBER := 0;
        lv_cc_email_id      VARCHAR2 (100) := 'ce_edi_alerts@deckers.com';

        CURSOR c_email_cur IS
            SELECT DISTINCT attribute1 email_id
              FROM xxdo.xxd_ont_edi_855_cust_t
             WHERE request_id = pv_request_id AND attribute1 IS NOT NULL;

        lv_result_msg       VARCHAR2 (4000);

        CURSOR c_cur (c_email_id VARCHAR2)
        IS
            SELECT hp.party_name customer_name, hca.account_number customer_number, xoec.customer_po_number,
                   xoec.ordered_quantity, xoec.upc_code, DECODE (xoec.deleted_from_header_iface, 'Y', 'Yes', 'No') po_rejected
              FROM xxdo.xxd_ont_edi_855_cust_t xoec, hz_cust_accounts hca, hz_parties hp
             WHERE     xoec.sold_to_org_id = hca.cust_account_id
                   AND hp.party_id = hca.party_id
                   AND xoec.request_id = pv_request_id
                   AND xoec.attribute1 = c_email_id;
    BEGIN
        BEGIN
            lv_directory_path   := NULL;

            SELECT directory_path
              INTO lv_directory_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_ONT_REPORT_OUT_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_directory_path   := NULL;
        END;

        lv_message   :=
               'Hi,'
            || CHR (10)
            || CHR (10)
            || 'Please Find the Attached Hard Reject Order Report. '
            || CHR (10)
            || CHR (10)
            || 'Regards,'
            || CHR (10)
            || 'SYSADMIN.'
            || CHR (10)
            || CHR (10)
            || 'Note: This is auto generated mail, please donot reply.';

        FOR c_email_rec IN c_email_cur
        LOOP
            l_file_seq   := l_file_seq + 1;
            lv_outbound_file   :=
                   pv_request_id
                || '_HardRejectOrderReport_'
                || TO_CHAR (SYSDATE, 'RRRR-MON-DD HH24:MI:SS')
                || l_file_seq
                || '.xls';

            lv_exc_file_name   :=
                lv_directory_path || lv_mail_delimiter || lv_outbound_file;
            lv_output_file   :=
                UTL_FILE.fopen (lv_directory_path, lv_outbound_file, 'W',
                                32767);

            IF UTL_FILE.is_open (lv_output_file)
            THEN
                lv_line   :=
                       'Customer Name'
                    || CHR (9)
                    || 'Customer Number'
                    || CHR (9)
                    || 'Customer PO Number'
                    || CHR (9)
                    || 'UPC#'
                    || CHR (9)
                    || 'Quantities'
                    || CHR (9)
                    || 'Full PO Rejected';

                UTL_FILE.put_line (lv_output_file, lv_line);

                FOR c_rec IN c_cur (c_email_rec.email_id)
                LOOP
                    lv_line   :=
                           NVL (c_rec.customer_name, '')
                        || CHR (9)
                        || NVL (c_rec.customer_number, '')
                        || CHR (9)
                        || NVL (c_rec.customer_po_number, '')
                        || CHR (9)
                        || NVL (c_rec.upc_code, '')
                        || CHR (9)
                        || NVL (c_rec.ordered_quantity, '')
                        || CHR (9)
                        || NVL (c_rec.po_rejected, '');

                    UTL_FILE.put_line (lv_output_file, lv_line);
                END LOOP;

                UTL_FILE.fclose (lv_output_file);
                xxdo_mail_pkg.send_mail (
                    pv_sender         => 'erp@deckers.com',
                    pv_recipients     => c_email_rec.email_id,
                    pv_ccrecipients   => lv_cc_email_id,
                    pv_subject        => 'Deckers Hard Reject Order Report',
                    pv_message        => lv_message,
                    pv_attachments    => lv_exc_file_name,
                    xv_result         => lv_result,
                    xv_result_msg     => lv_result_msg);
            END IF;

            BEGIN
                UTL_FILE.fremove (lv_directory_path, lv_exc_file_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Unable to delete the execption report file- '
                        || SQLERRM);
            END;
        END LOOP;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_PATH: File location or filename was invalid.';
            raise_application_error (-20101, lv_err_msg);
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
            raise_application_error (-20102, lv_err_msg);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILEHANDLE: The file handle was invalid.';
            raise_application_error (-20103, lv_err_msg);
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
            raise_application_error (-20104, lv_err_msg);
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'READ_ERROR: An operating system error occurred during the read operation.';
            raise_application_error (-20105, lv_err_msg);
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'WRITE_ERROR: An operating system error occurred during the write operation.';
            raise_application_error (-20106, lv_err_msg);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            raise_application_error (-20107, lv_err_msg);
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILENAME: The filename parameter is invalid.';
            raise_application_error (-20108, lv_err_msg);
        WHEN OTHERS
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            UTL_FILE.fremove (lv_directory_path, lv_exc_file_name);
            lv_err_msg   :=
                SUBSTR (
                       'Error while creating or writing the data into the file.'
                    || SQLERRM,
                    1,
                    2000);
            raise_application_error (-20109, lv_err_msg);
    END generate_report_prc;

    -- End Added for CCR0009954 -----
    -- Start changes for CCR0007226
    --------------------------------------------------------------------
    -- Procdure to validate for any inactive SKU lines in IFACE tables
    -- for specific customers and then delete them. Also this will capture
    -- the same set of data to send Hard Reject "R2" status in 855
    --------------------------------------------------------------------

    PROCEDURE edi_855_validation (p_operating_unit   IN NUMBER,
                                  p_osid             IN NUMBER)
    IS
        CURSOR get_inactive_lines_c IS
            SELECT DISTINCT
                   ohia.order_source_id, -- Adding DISTINCT to avoild duplicates
                   ohia.orig_sys_document_ref,
                   ohia.sold_to_org_id,
                   ohia.customer_po_number,
                   ohia.ordered_date,
                   olia.orig_sys_line_ref,
                   olia.ship_to_org_id,
                   olia.inventory_item_id,
                   olia.line_number,
                   olia.attribute7
                       customer_item,
                   NVL (olia.unit_selling_price, olia.attribute13)
                       unit_selling_price,
                   olia.request_date,
                   olia.ordered_quantity,
                   olia.order_quantity_uom
                       uom_code,
                   (SELECT attribute11
                      FROM mtl_system_items_b msib
                     WHERE     msib.inventory_item_id =
                               olia.inventory_item_id
                           AND msib.organization_id = gn_master_org_id)
                       upc_code,
                   'N'
                       deleted_from_header_iface,
                   'Y'
                       deleted_from_lines_iface,
                   'Y'
                       send_hard_reject,
                   'N'
                       edi_855_processed,
                   ohia.tp_attribute15
              FROM oe_headers_iface_all ohia, oe_lines_iface_all olia
             WHERE     ohia.orig_sys_document_ref =
                       olia.orig_sys_document_ref
                   AND ohia.org_id = olia.org_id
                   AND ohia.order_source_id = p_osid
                   AND ohia.org_id = p_operating_unit
                   -- Customer Inclusion
                   AND EXISTS
                           (SELECT 1
                              FROM fnd_lookup_values flv
                             WHERE     flv.lookup_type =
                                       'XXD_ONT_DEL_IFACE_INACTIVE_SKU'
                                   AND flv.language = USERENV ('LANG')
                                   AND flv.enabled_flag = 'Y'
                                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                   flv.start_date_active,
                                                                   TRUNC (
                                                                       SYSDATE))
                                                           AND NVL (
                                                                   flv.end_date_active,
                                                                   TRUNC (
                                                                       SYSDATE))
                                   AND ((flv.meaning <> 'ALL' AND ohia.sold_to_org_id = TO_NUMBER (flv.lookup_code)) OR (flv.meaning = 'ALL' AND 1 = 1)))
                   -- SKU Validation
                   AND EXISTS
                           (SELECT 1
                              FROM mtl_system_items_b msib, mtl_system_items_b msib1, fnd_lookup_values flv_inv_org
                             WHERE     msib.organization_id =
                                       gn_master_org_id
                                   AND msib.inventory_item_id =
                                       olia.inventory_item_id
                                   AND msib.enabled_flag = 'Y'
                                   AND msib.inventory_item_status_code =
                                       'Inactive'
                                   AND msib1.inventory_item_id =
                                       msib.inventory_item_id
                                   AND msib1.organization_id =
                                       TO_NUMBER (flv_inv_org.lookup_code)
                                   AND TO_NUMBER (flv_inv_org.description) =
                                       p_operating_unit
                                   AND flv_inv_org.lookup_type =
                                       'XXD_ONT_EDI_INV_ORG'
                                   AND flv_inv_org.language =
                                       USERENV ('LANG')
                                   AND flv_inv_org.enabled_flag = 'Y'
                                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                   flv_inv_org.start_date_active,
                                                                   TRUNC (
                                                                       SYSDATE))
                                                           AND NVL (
                                                                   flv_inv_org.end_date_active,
                                                                   TRUNC (
                                                                       SYSDATE))
                                   AND msib1.enabled_flag = 'Y'
                                   AND msib1.inventory_item_status_code =
                                       'Inactive')
            -- Start changes for CCR0008488
            UNION
            SELECT DISTINCT ohia.order_source_id, ohia.orig_sys_document_ref, ohia.sold_to_org_id,
                            ohia.customer_po_number, ohia.ordered_date, olia.orig_sys_line_ref,
                            olia.ship_to_org_id, olia.inventory_item_id, olia.line_number,
                            olia.attribute7 customer_item, NVL (olia.unit_selling_price, olia.attribute13) unit_selling_price, olia.request_date,
                            olia.ordered_quantity, olia.order_quantity_uom uom_code, olia.global_attribute2 upc_code,
                            'N' deleted_from_header_iface, 'Y' deleted_from_lines_iface, 'Y' send_hard_reject,
                            'N' edi_855_processed, ohia.tp_attribute15
              FROM oe_headers_iface_all ohia, oe_lines_iface_all olia
             WHERE     ohia.orig_sys_document_ref =
                       olia.orig_sys_document_ref
                   AND ohia.org_id = olia.org_id
                   AND olia.global_attribute2 IS NOT NULL
                   AND olia.inventory_item_id IS NULL
                   AND ohia.order_source_id = p_osid
                   AND ohia.org_id = p_operating_unit
                   -- Customer Inclusion
                   AND EXISTS
                           (SELECT 1
                              FROM fnd_lookup_values flv
                             WHERE     flv.lookup_type =
                                       'XXD_ONT_DEL_IFACE_INACTIVE_SKU'
                                   AND flv.language = USERENV ('LANG')
                                   AND flv.enabled_flag = 'Y'
                                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                   flv.start_date_active,
                                                                   TRUNC (
                                                                       SYSDATE))
                                                           AND NVL (
                                                                   flv.end_date_active,
                                                                   TRUNC (
                                                                       SYSDATE))
                                   AND ((flv.meaning <> 'ALL' AND ohia.sold_to_org_id = TO_NUMBER (flv.lookup_code)) OR (flv.meaning = 'ALL' AND 1 = 1)));

        -- End changes for CCR0008488

        CURSOR get_headers_c IS
            SELECT orig_sys_document_ref
              FROM oe_headers_iface_all ohia
             WHERE     ohia.order_source_id = p_osid
                   AND ohia.org_id = p_operating_unit
                   AND ohia.operation_code = 'INSERT'  -- Added for CCR0008175
                   AND NOT EXISTS
                           (SELECT 1
                              FROM oe_lines_iface_all olia
                             WHERE     ohia.orig_sys_document_ref =
                                       olia.orig_sys_document_ref
                                   AND ohia.org_id = olia.org_id);

        ln_count   NUMBER DEFAULT 0;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'EDI_855_VALIDATION Start');
        fnd_file.put_line (fnd_file.LOG, 'Inactive SKU Lines in IFACE');

        FOR inactive_lines_rec IN get_inactive_lines_c
        LOOP
            ln_count   := ln_count + 1;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Cust Account ID : '
                || inactive_lines_rec.sold_to_org_id
                || '. Line Ref : '
                || inactive_lines_rec.orig_sys_line_ref
                || '. Item ID : '
                || inactive_lines_rec.inventory_item_id);

            -- Capture Inactive SKU Lines
            INSERT INTO xxdo.xxd_ont_edi_855_cust_t (
                            order_source_id,
                            orig_sys_document_ref,
                            sold_to_org_id,
                            customer_po_number,
                            ordered_date,
                            orig_sys_line_ref,
                            ship_to_org_id,
                            inventory_item_id,
                            line_number,
                            customer_item,
                            unit_selling_price,
                            request_date,
                            ordered_quantity,
                            uom_code,
                            upc_code,
                            deleted_from_header_iface,
                            deleted_from_lines_iface,
                            send_hard_reject,
                            edi_855_processed,
                            org_id,
                            request_id,
                            creation_date,
                            created_by,
                            last_update_date,
                            last_updated_by,
                            last_update_login,
                            attribute1)                -- Added for CCR0009954
                     VALUES (inactive_lines_rec.order_source_id,
                             inactive_lines_rec.orig_sys_document_ref,
                             inactive_lines_rec.sold_to_org_id,
                             inactive_lines_rec.customer_po_number,
                             inactive_lines_rec.ordered_date,
                             inactive_lines_rec.orig_sys_line_ref,
                             inactive_lines_rec.ship_to_org_id,
                             inactive_lines_rec.inventory_item_id,
                             inactive_lines_rec.line_number,
                             inactive_lines_rec.customer_item,
                             inactive_lines_rec.unit_selling_price,
                             inactive_lines_rec.request_date,
                             inactive_lines_rec.ordered_quantity,
                             inactive_lines_rec.uom_code,
                             inactive_lines_rec.upc_code,
                             inactive_lines_rec.deleted_from_header_iface,
                             inactive_lines_rec.deleted_from_lines_iface,
                             inactive_lines_rec.send_hard_reject,
                             inactive_lines_rec.edi_855_processed,
                             p_operating_unit,
                             fnd_global.conc_request_id,
                             SYSDATE,
                             fnd_global.user_id,
                             SYSDATE,
                             fnd_global.user_id,
                             fnd_global.login_id,
                             inactive_lines_rec.tp_attribute15); -- Added for CCR0009954

            -- Delete Inactive SKU Lines including duplicates
            DELETE oe_lines_iface_all
             WHERE     orig_sys_line_ref =
                       inactive_lines_rec.orig_sys_line_ref
                   AND orig_sys_document_ref =
                       inactive_lines_rec.orig_sys_document_ref;  --CCR0009335

            fnd_file.put_line (fnd_file.LOG,
                               'Delete Count : ' || SQL%ROWCOUNT);
        END LOOP;

        -- Delete Header if there are no lines
        FOR headers_rec IN get_headers_c
        LOOP
            fnd_file.put_line (
                fnd_file.LOG,
                   'Deleted the Header IFACE Record for Orig Sys Doc Ref : '
                || headers_rec.orig_sys_document_ref);

            DELETE oe_headers_iface_all
             WHERE orig_sys_document_ref = headers_rec.orig_sys_document_ref;

            UPDATE xxdo.xxd_ont_edi_855_cust_t
               SET deleted_from_header_iface   = 'Y'
             WHERE orig_sys_document_ref = headers_rec.orig_sys_document_ref;
        END LOOP;

        generate_report_prc (fnd_global.conc_request_id); -- Added for CCR0009954
        fnd_file.put_line (fnd_file.LOG,
                           'Total Line Record Count : ' || ln_count);
        COMMIT;
        fnd_file.put_line (fnd_file.LOG, 'EDI_855_VALIDATION End');
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            fnd_file.put_line (
                fnd_file.LOG,
                'SQLCODE : ' || SQLCODE || '. ERROR Message : ' || SQLERRM);
    END edi_855_validation;

    -- End changes for CCR0007226
    --1.6 End : Added by Infosys for CCR0007225
    -- Start of changes By Siva Boothathan for CCR0008604
    --------------------------------------------------------------------
    -- Added by Sivakumar Boothathan on 04/21/2020
    -- Procdure to validate if the customer is enabled for drop shipments
    -- The goal for this procuedure is to change the order type to :
    -- Consumer Direct - US if
    -- The customer number exists in the lookup:XXD_ONT_B2B2C_CUSTOMERS
    -- And also the interface records should have deliver to org ID
    --------------------------------------------------------------------

    PROCEDURE get_b2b2c_ordertype (p_operating_unit   IN NUMBER,
                                   p_osid             IN NUMBER)
    IS
        ---------------------------------------------------------------
        -- Cursor to select the records in the interface that are
        -- eligble for changing the order type for drop shipments
        -- orders.
        --------------------------------------------------------------
        CURSOR cur_get_b2b2c_order_type IS
            ------------------------------
            -- Query to get the order type
            ------------------------------
            SELECT ohia.orig_sys_document_ref osdr, TO_NUMBER (flv.attribute3) b2b_order_type_id
              FROM apps.oe_headers_iface_all ohia, apps.fnd_lookup_values flv
             WHERE     ohia.org_id = TO_NUMBER (flv.attribute1)
                   AND ohia.sold_to_org_id = flv.attribute2
                   AND ohia.order_source_id = TO_NUMBER (flv.attribute4)
                   AND flv.lookup_type = 'XXD_ONT_B2B2C_CUSTOMERS'
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                    TRUNC (SYSDATE))
                                           AND NVL (flv.end_date_active,
                                                    TRUNC (SYSDATE))
                   AND ohia.deliver_to_org_id IS NOT NULL
                   AND ohia.org_id = p_operating_unit
                   AND ohia.operation_code = 'INSERT'
                   AND ohia.request_id IS NULL
                   AND ohia.error_flag IS NULL
                   AND ohia.order_source_id = p_osid;

        ln_record_count   NUMBER := 0;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'GET_B2B2C_ORDERTYPE Start');

        FOR i IN cur_get_b2b2c_order_type
        LOOP
            UPDATE apps.oe_headers_iface_all
               SET order_type_id   = i.b2b_order_type_id
             WHERE     orig_sys_document_ref = i.osdr
                   AND org_id = p_operating_unit
                   AND operation_code = 'INSERT'
                   AND request_id IS NULL
                   AND error_flag IS NULL
                   AND order_source_id = p_osid;

            ln_record_count   := ln_record_count + SQL%ROWCOUNT;
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
            'B2B Order Type Updated for records = ' || ln_record_count);
        COMMIT;
        fnd_file.put_line (fnd_file.LOG, 'GET_B2B2C_ORDERTYPE End');
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            fnd_file.put_line (
                fnd_file.LOG,
                'SQLCODE : ' || SQLCODE || '. ERROR Message : ' || SQLERRM);
    END get_b2b2c_ordertype;

    -- End of changes By Siva Boothathan for CCR0008604

    -- START Changes as per CCR0008488

    FUNCTION get_hz_bill_to_org_id (p_org_id NUMBER, p_customer_id NUMBER)
        RETURN NUMBER
    IS
        l_proc_name       VARCHAR2 (240) := 'GET_BILL_TO_ORG_ID';
        l_org_id          NUMBER;
        l_customer_id     NUMBER;
        x_site_use_id     NUMBER;
        l_counter         NUMBER;
        l_ship_to_site    NUMBER;
        l_primary_site    NUMBER;
        l_brand           VARCHAR2 (240);
        l_override_site   NUMBER;
    BEGIN
        SELECT cust_account_id, attribute1
          INTO l_customer_id, l_brand
          FROM apps.hz_cust_accounts rac
         WHERE rac.cust_account_id = p_customer_id;

        SELECT MAX (rsua.site_use_id), COUNT (*)
          INTO l_override_site, l_counter
          FROM apps.ra_addresses_morg raa, apps.ra_site_uses_morg rsua
         WHERE     raa.org_id = p_org_id
               AND raa.customer_id = l_customer_id
               AND raa.status = 'A'
               AND rsua.address_id = raa.address_id
               AND rsua.site_use_code = 'BILL_TO'
               AND rsua.status = 'A'
               AND SUBSTR (UPPER (rsua.location), 0, LENGTH (l_brand)) =
                   UPPER (l_brand);

        IF l_counter != 1
        THEN
            l_override_site   := NULL;
        END IF;

        BEGIN
            SELECT rsua.site_use_id
              INTO l_primary_site
              FROM apps.ra_addresses_morg raa, apps.ra_site_uses_morg rsua
             WHERE     raa.org_id = p_org_id
                   AND raa.customer_id = l_customer_id
                   AND raa.status = 'A'
                   AND rsua.address_id = raa.address_id
                   AND rsua.site_use_code = 'BILL_TO'
                   AND rsua.status = 'A'
                   AND rsua.primary_flag = 'Y'
                   AND NOT EXISTS
                           (SELECT NULL
                              FROM do_custom.do_brands
                             WHERE UPPER (brand_name) =
                                   SUBSTR (UPPER (rsua.location),
                                           0,
                                           LENGTH (brand_name)));
        EXCEPTION
            WHEN TOO_MANY_ROWS
            THEN
                l_primary_site   := NULL;
            WHEN NO_DATA_FOUND
            THEN
                SELECT COUNT (*), MAX (rsua.site_use_id)
                  INTO l_counter, l_primary_site
                  FROM apps.ra_addresses_morg raa, apps.ra_site_uses_morg rsua
                 WHERE     raa.customer_id = l_customer_id
                       AND raa.status = 'A'
                       AND raa.org_id = l_org_id
                       AND rsua.address_id = raa.address_id
                       AND rsua.site_use_code = 'BILL_TO'
                       AND rsua.status = 'A'
                       AND NOT EXISTS
                               (SELECT NULL
                                  FROM do_custom.do_brands
                                 WHERE UPPER (brand_name) =
                                       SUBSTR (UPPER (rsua.location),
                                               0,
                                               LENGTH (brand_name)));

                IF l_counter != 1
                THEN
                    l_primary_site   := NULL;
                END IF;
        END;

        BEGIN
            SELECT bill_to_site_use_id
              INTO x_site_use_id
              FROM apps.ra_site_uses_morg
             WHERE site_use_id =
                   get_hz_ship_to_org_id (p_org_id, p_customer_id);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                x_site_use_id   := NULL;
        END;

        RETURN NVL (l_primary_site, NVL (x_site_use_id, l_override_site));
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_hz_bill_to_org_id;

    FUNCTION get_hz_ship_to_org_id (p_org_id NUMBER, p_customer_id NUMBER)
        RETURN NUMBER
    IS
        l_proc_name     VARCHAR2 (240) := 'GET_SHIP_TO_ORG_ID';
        l_org_id        NUMBER;
        l_customer_id   NUMBER;
        x_site_use_id   NUMBER;
        l_counter       NUMBER;
    BEGIN
        SELECT cust_account_id
          INTO l_customer_id
          FROM apps.hz_cust_accounts rac
         WHERE rac.cust_account_id = p_customer_id;

        IF l_customer_id IS NOT NULL
        THEN
            BEGIN
                SELECT rsua.site_use_id
                  INTO x_site_use_id
                  FROM apps.ra_addresses_morg raa, apps.ra_site_uses_morg rsua
                 WHERE     raa.org_id = p_org_id
                       AND raa.customer_id = l_customer_id
                       AND raa.status = 'A'
                       AND rsua.address_id = raa.address_id
                       AND rsua.site_use_code = 'SHIP_TO'
                       AND rsua.status = 'A'
                       AND rsua.primary_flag = 'Y';
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    BEGIN
                        SELECT COUNT (*), MAX (rsua.site_use_id)
                          INTO l_counter, x_site_use_id
                          FROM apps.ra_addresses_morg raa, apps.ra_site_uses_morg rsua
                         WHERE     raa.customer_id = l_customer_id
                               AND raa.status = 'A'
                               AND raa.org_id = p_org_id
                               AND rsua.address_id = raa.address_id
                               AND rsua.site_use_code = 'SHIP_TO'
                               AND rsua.status = 'A';

                        IF l_counter = 1
                        THEN
                            RETURN x_site_use_id;
                        END IF;

                        SELECT rsua.site_use_id
                          INTO x_site_use_id
                          FROM apps.ra_addresses_morg raa, apps.ra_site_uses_morg rsua
                         WHERE     raa.org_id = p_org_id
                               AND raa.customer_id IN
                                       (SELECT related_cust_account_id
                                          FROM hz_cust_acct_relate_all hcr, hz_cust_accounts hca_child, hz_cust_accounts hca_parent
                                         WHERE     hcr.cust_account_id =
                                                   l_customer_id
                                               AND hca_parent.cust_account_id =
                                                   hcr.related_cust_account_id
                                               AND hca_parent.attribute1 =
                                                   'ALL BRAND'
                                               AND hcr.cust_account_id =
                                                   hca_child.cust_account_id
                                               AND hca_parent.party_id =
                                                   hca_child.party_id)
                               AND raa.status = 'A'
                               AND rsua.address_id = raa.address_id
                               AND rsua.site_use_code = 'SHIP_TO'
                               AND rsua.status = 'A'
                               AND rsua.primary_flag = 'Y';

                        IF x_site_use_id IS NOT NULL
                        THEN
                            RETURN x_site_use_id;
                        END IF;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            x_site_use_id   := NULL;
                    END;
            END;
        END IF;

        RETURN x_site_use_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_hz_ship_to_org_id;

    FUNCTION get_hz_order_type_id (p_org_id NUMBER, p_customer_id NUMBER)
        RETURN NUMBER
    IS
        l_proc_name         VARCHAR2 (240) := 'GET_ORDER_TYPE_ID';
        l_bill_to_org_id    NUMBER;
        l_ship_to_org_id    NUMBER;
        l_order_type_id     NUMBER;
        x_order_type_name   VARCHAR2 (240);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'GET_HZ_ORDER_TYPE_ID Start');
        l_bill_to_org_id   := get_hz_bill_to_org_id (p_org_id, p_customer_id);
        fnd_file.put_line (fnd_file.LOG,
                           'BILL_TO_ORG_ID = ' || l_bill_to_org_id);
        l_ship_to_org_id   := get_hz_ship_to_org_id (p_org_id, p_customer_id);
        fnd_file.put_line (fnd_file.LOG,
                           'SHIP_TO_ORG_ID = ' || l_ship_to_org_id);

        BEGIN
            SELECT order_type_id
              INTO l_order_type_id
              FROM hz_cust_site_uses_all
             WHERE site_use_id = l_bill_to_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_order_type_id   := NULL;
        END;

        fnd_file.put_line (fnd_file.LOG,
                           'BILL_TO ORDER_TYPE_ID = ' || l_order_type_id);

        IF l_order_type_id IS NULL
        THEN
            BEGIN
                SELECT order_type_id
                  INTO l_order_type_id
                  FROM hz_cust_site_uses_all
                 WHERE site_use_id = l_ship_to_org_id;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'SHIP_TO ORDER_TYPE_ID = ' || l_order_type_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_order_type_id   := NULL;
            END;
        END IF;

        RETURN l_order_type_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_hz_order_type_id;

    --To Validate and Update EDI 850 SPS Enablement

    PROCEDURE edi_850_sps_validation (p_operating_unit   IN NUMBER,
                                      p_osid             IN NUMBER)
    IS
        -- To fetch EDI-850 SPS Service Enable and Customer Exists in Lookup
        CURSOR c_edi_sps_dtls IS
              SELECT ohia.org_id, ohia.orig_sys_document_ref osdr, ohia.order_source_id,
                     ohia.global_attribute1 edi_po_type, TO_NUMBER (flv.attribute3) sps_order_type_id, ohia.creation_date,
                     ohia.request_date, hca.cust_account_id
                FROM oe_headers_iface_all ohia, fnd_lookup_values flv, hz_cust_accounts hca
               WHERE     1 = 1
                     AND ohia.sold_to_org_id = hca.cust_account_id
                     AND hca.account_number = flv.lookup_code
                     AND flv.lookup_type = 'XXDO_EDI_CUSTOMERS'
                     AND flv.language = USERENV ('LANG')
                     AND NVL (flv.enabled_flag, 'N') = 'Y'
                     AND NVL (flv.attribute1, 'N') = 'Y' --SPS: Y and NON-SPS: N
                     AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                      TRUNC (SYSDATE))
                                             AND NVL (flv.end_date_active,
                                                      TRUNC (SYSDATE))
                     AND ohia.order_type_id IS NULL --For SPS, Order Type should be NULL
                     AND ohia.global_attribute1 IS NOT NULL --For SPS, EDI PO Type should be NOT NULL
                     AND ohia.error_flag IS NULL
                     AND ohia.request_id IS NULL
                     AND ohia.operation_code = 'INSERT'
                     AND ohia.order_source_id = p_osid           --Source: EDI
                     AND ohia.org_id = p_operating_unit
            ORDER BY hca.cust_account_id, ohia.org_id; -- Added for CCR0010148

        lv_vs_edi_po_type        VARCHAR2 (150) := NULL;
        lv_vs_ord_type           VARCHAR2 (150) := NULL;
        lv_new_ord_type          VARCHAR2 (150) := NULL;
        ln_ord_type_id           NUMBER := 0;
        ln_new_ord_type_id       NUMBER := 0;
        ln_line_pack_instr_cnt   NUMBER := 0;
        ln_ci_ord_type_count     NUMBER := 0;
        ln_cur_cust_account_id   NUMBER := -1;         -- Added for CCR0010148
        ln_cur_org_id            NUMBER := -1;         -- Added for CCR0010148
        lc_edi_po_type           VARCHAR2 (150) := 'X'; -- Added for CCR0010407
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'EDI_850_SPS_VALIDATION Start');

        FOR i IN c_edi_sps_dtls
        LOOP
            ln_ord_type_id   := NULL;                  -- Added for CCR0010407

            IF i.edi_po_type IS NOT NULL -- EDI-850 SPS Enabled and Customer Exists in Lookup
            THEN
                ---------------------------------------------
                --To Update Order Type for SPS Enabled
                ---------------------------------------------
                --To Validate EDI PO Type from Independent Valueset
                BEGIN
                    SELECT flv.flex_value
                      INTO lv_vs_edi_po_type
                      FROM apps.fnd_flex_value_sets fs, apps.fnd_flex_values_vl flv
                     WHERE     fs.flex_value_set_id = flv.flex_value_set_id
                           AND fs.flex_value_set_name = 'XXD_EDI_PO_TYPES'
                           AND flv.flex_value = i.edi_po_type
                           AND NVL (flv.enabled_flag, 'N') = 'Y'
                           AND flv.summary_flag = 'N'
                           AND TRUNC (SYSDATE) BETWEEN NVL (
                                                           flv.start_date_active,
                                                           TRUNC (SYSDATE))
                                                   AND NVL (
                                                           flv.end_date_active,
                                                           TRUNC (SYSDATE));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_vs_edi_po_type   := NULL;
                END;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'EDI-PO type return value from Valueset is: '
                    || lv_vs_edi_po_type);

                IF lv_vs_edi_po_type IS NOT NULL
                THEN
                    --To get Order type by Scan 'EDI PO Type' in Dependent Valueset
                    BEGIN
                        -- Start modification for CCR0010407
                        -- if ln_cur_org_id<>i.org_id or ln_cur_cust_account_id<>i.cust_account_id then-- Added for CCR0010148
                        IF    ln_cur_org_id <> i.org_id
                           OR ln_cur_cust_account_id <> i.cust_account_id
                           OR lc_edi_po_type <> i.edi_po_type
                        THEN
                            -- End modification for CCR0010407
                            ln_ord_type_id   :=
                                get_hz_order_type_id (i.org_id,
                                                      i.cust_account_id);
                        END IF;                        -- Added for CCR0010148

                        ln_cur_cust_account_id   := i.cust_account_id; -- Added for CCR0010148
                        ln_cur_org_id            := i.org_id; -- Added for CCR0010148
                        lc_edi_po_type           := i.edi_po_type; -- Added for CCR0010407

                        SELECT COUNT (1)
                          INTO ln_ci_ord_type_count
                          FROM apps.oe_lookups
                         WHERE     lookup_type = 'XXDO_OM_CI_ORDER_TYPES'
                               AND enabled_flag = 'Y'
                               AND lookup_code = ln_ord_type_id
                               AND NVL (TRUNC (end_date_active),
                                        TRUNC (SYSDATE + 1)) >=
                                   TRUNC (SYSDATE);

                        IF     ln_ord_type_id IS NOT NULL
                           AND ln_ci_ord_type_count > 0
                        THEN
                            ln_ord_type_id   := NULL;
                        END IF;

                        IF ln_ord_type_id IS NULL
                        THEN
                            SELECT flv.flex_value, ott.transaction_type_id
                              INTO lv_vs_ord_type, ln_ord_type_id
                              FROM apps.fnd_flex_value_sets fs, apps.fnd_flex_values_vl flv, apps.oe_transaction_types_tl ott
                             WHERE     fs.flex_value_set_id =
                                       flv.flex_value_set_id
                                   AND flv.flex_value = ott.name
                                   AND fs.flex_value_set_name =
                                       'XXD_EDI_OM_ORDER_TYPES'
                                   AND NVL (flv.enabled_flag, 'N') = 'Y'
                                   AND flv.summary_flag = 'N'
                                   AND flv.parent_flex_value_low =
                                       lv_vs_edi_po_type
                                   AND TO_NUMBER (flv.attribute1) =
                                       p_operating_unit
                                   AND ott.language = USERENV ('LANG')
                                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                   flv.start_date_active,
                                                                   TRUNC (
                                                                       SYSDATE))
                                                           AND NVL (
                                                                   flv.end_date_active,
                                                                   TRUNC (
                                                                       SYSDATE));

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Derived SPS Order Type from XXD_EDI_OM_ORDER_TYPES :'
                                || ln_ord_type_id);
                        END IF;

                        UPDATE apps.oe_headers_iface_all
                           SET order_type_id = ln_ord_type_id, change_sequence = 1, force_apply_flag = 'Y',
                               attribute9 = DECODE (lv_vs_edi_po_type, 'XD', 'Y'), request_id = NULL, error_flag = NULL,
                               last_update_date = SYSDATE, last_updated_by = gn_batch_user_id
                         WHERE     orig_sys_document_ref = i.osdr
                               AND org_id = p_operating_unit
                               AND order_source_id = p_osid
                               AND operation_code = 'INSERT';

                        UPDATE apps.oe_lines_iface_all
                           SET change_sequence = 1, request_id = NULL, error_flag = NULL,
                               last_update_date = SYSDATE, last_updated_by = gn_batch_user_id
                         WHERE     orig_sys_document_ref = i.osdr
                               AND org_id = p_operating_unit
                               AND order_source_id = p_osid
                               AND operation_code = 'INSERT';
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'EXP-No Data Found, SPS Order Type Derivation failed');

                            UPDATE apps.oe_headers_iface_all
                               SET request_id = 0000020, error_flag = 'Y', last_update_date = SYSDATE,
                                   last_updated_by = gn_batch_user_id
                             WHERE     orig_sys_document_ref = i.osdr
                                   AND org_id = p_operating_unit
                                   AND order_source_id = p_osid
                                   AND operation_code = 'INSERT';
                        WHEN TOO_MANY_ROWS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'EXP-Too Many Rows, SPS Order Type Derivation based on XXD_EDI_OM_ORDER_TYPES. Now deriving value from XXDO_OM_SEASON_CODES');

                            BEGIN
                                SELECT DISTINCT ott.transaction_type_id, ott.name
                                  INTO ln_new_ord_type_id, lv_new_ord_type
                                  FROM apps.oe_transaction_types_tl ott, apps.fnd_lookup_values flv
                                 WHERE     ott.transaction_type_id =
                                           TO_NUMBER (flv.attribute7)
                                       AND ott.language = USERENV ('LANG')
                                       AND flv.lookup_type =
                                           'XXDO_OM_SEASON_CODES'
                                       AND flv.language = USERENV ('LANG')
                                       AND NVL (flv.enabled_flag, 'N') = 'Y'
                                       AND ((lv_vs_edi_po_type = 'BK' AND NVL (flv.tag, 'XX') = 'BLK') OR (lv_vs_edi_po_type <> 'BK' AND NVL (flv.tag, 'XX') <> 'BLK'))
                                       AND TO_NUMBER (flv.attribute5) =
                                           p_operating_unit
                                       AND NVL (
                                               TRUNC (flv.start_date_active),
                                               TRUNC (SYSDATE)) <=
                                           TRUNC (SYSDATE)
                                       AND NVL (TRUNC (flv.end_date_active),
                                                TRUNC (SYSDATE)) >=
                                           TRUNC (SYSDATE)
                                       AND i.creation_date >=
                                           TRUNC (
                                               TO_DATE (
                                                   flv.attribute1,
                                                   'RRRR/MM/DD HH24:MI:SS'))
                                       AND i.creation_date <=
                                           TRUNC (
                                               TO_DATE (
                                                   flv.attribute2,
                                                   'RRRR/MM/DD HH24:MI:SS'))
                                       AND i.request_date >=
                                           TRUNC (
                                               TO_DATE (
                                                   flv.attribute3,
                                                   'RRRR/MM/DD HH24:MI:SS'))
                                       AND i.request_date <=
                                           TRUNC (
                                               TO_DATE (
                                                   flv.attribute4,
                                                   'RRRR/MM/DD HH24:MI:SS'));

                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Derived SPS New Order Type from XXDO_OM_SEASON_CODES is: '
                                    || lv_new_ord_type);

                                UPDATE apps.oe_headers_iface_all
                                   SET order_type_id = ln_new_ord_type_id, change_sequence = 1, force_apply_flag = 'Y',
                                       request_id = NULL, error_flag = NULL, last_update_date = SYSDATE,
                                       last_updated_by = gn_batch_user_id
                                 WHERE     orig_sys_document_ref = i.osdr
                                       AND org_id = p_operating_unit
                                       AND order_source_id = p_osid
                                       AND operation_code = 'INSERT';

                                UPDATE apps.oe_lines_iface_all
                                   SET change_sequence = 1, request_id = NULL, error_flag = NULL,
                                       last_update_date = SYSDATE, last_updated_by = gn_batch_user_id
                                 WHERE     orig_sys_document_ref = i.osdr
                                       AND org_id = p_operating_unit
                                       AND order_source_id = p_osid
                                       AND operation_code = 'INSERT';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'EXP-Too Many Rows, SPS Order Type Derivation failed');

                                    UPDATE apps.oe_headers_iface_all
                                       SET request_id = 0000020, error_flag = 'Y', last_update_date = SYSDATE,
                                           last_updated_by = gn_batch_user_id
                                     WHERE     orig_sys_document_ref = i.osdr
                                           AND org_id = p_operating_unit
                                           AND order_source_id = p_osid
                                           AND operation_code = 'INSERT';
                            END;
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'EXP-Others, SPS Order Type Derivation failed');

                            UPDATE apps.oe_headers_iface_all
                               SET request_id = 0000020, error_flag = 'Y', last_update_date = SYSDATE,
                                   last_updated_by = gn_batch_user_id
                             WHERE     orig_sys_document_ref = i.osdr
                                   AND org_id = p_operating_unit
                                   AND order_source_id = p_osid
                                   AND operation_code = 'INSERT';
                    END;
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'EDI-PO type return from Valueset is NULL, Skipped Order Type Updation: ');
                END IF;                              -- END IF for EDI PO Type

                -------------------------------------------------
                --To Update Packing Instructions for SPS Enabled
                -------------------------------------------------
                BEGIN
                    SELECT COUNT (olia.attribute3)
                      INTO ln_line_pack_instr_cnt
                      FROM apps.oe_headers_iface_all ohia, apps.oe_lines_iface_all olia
                     WHERE     1 = 1
                           AND ohia.orig_sys_document_ref =
                               olia.orig_sys_document_ref
                           AND ohia.org_id = p_operating_unit
                           AND ohia.order_source_id = p_osid
                           AND ohia.orig_sys_document_ref = i.osdr;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_line_pack_instr_cnt   := 0;
                END;

                IF ln_line_pack_instr_cnt <> 0
                THEN
                    UPDATE apps.oe_headers_iface_all
                       SET attribute16   = 'M'
                     WHERE     orig_sys_document_ref = i.osdr
                           AND org_id = p_operating_unit
                           AND order_source_id = p_osid
                           AND operation_code = 'INSERT';

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Packing Instructions updated in Order Hdr Iface as: ''M''');
                ELSE
                    UPDATE apps.oe_headers_iface_all
                       SET attribute16   = 'S'
                     WHERE     orig_sys_document_ref = i.osdr
                           AND org_id = p_operating_unit
                           AND order_source_id = p_osid
                           AND operation_code = 'INSERT';

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Packing Instructions updated in Order Hdr Iface as: ''S''');
                END IF;
            END IF;           -- End If for EDI PO Type Exists and SPS Enabled
        END LOOP;

        COMMIT;
        fnd_file.put_line (fnd_file.LOG, 'EDI_850_SPS_VALIDATION End');
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            fnd_file.put_line (
                fnd_file.LOG,
                'SQLCODE : ' || SQLCODE || '. ERROR Message : ' || SQLERRM);
    END edi_850_sps_validation;

    --To Update EDI 860 Exclusion details

    PROCEDURE edi_860_exclusion (p_operating_unit   IN NUMBER,
                                 p_osid             IN NUMBER)
    IS
        -- To fetch EDI-860 Exclusion details
        CURSOR c_edi_excl_dtls IS
            SELECT DISTINCT ohia.org_id, ohia.orig_sys_document_ref osdr
              FROM apps.oe_order_headers_all oha, apps.oe_headers_iface_all ohia, apps.fnd_lookup_values flv
             WHERE     1 = 1
                   AND oha.orig_sys_document_ref = ohia.orig_sys_document_ref
                   AND oha.org_id = ohia.org_id
                   AND ohia.operation_code = 'UPDATE'
                   AND ohia.error_flag IS NULL
                   AND ohia.request_id IS NULL
                   AND flv.lookup_type = 'XXD_ONT_EDI_860_EXCLUSION'
                   AND flv.language = USERENV ('LANG')
                   AND NVL (flv.enabled_flag, 'N') = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (
                                                       flv.start_date_active,
                                                       SYSDATE))
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                   AND oha.org_id = TO_NUMBER (flv.attribute1) --Operating Unit
                   AND ((flv.attribute2 IS NULL AND 1 = 1)          --Customer
                                                           OR (flv.attribute2 IS NOT NULL AND oha.sold_to_org_id = TO_NUMBER (flv.attribute2)))
                   AND ((flv.attribute3 IS NULL AND 1 = 1)        --Order Type
                                                           OR (flv.attribute3 IS NOT NULL AND oha.order_type_id = TO_NUMBER (flv.attribute3)))
                   AND ((flv.attribute4 IS NULL AND 1 = 1)      --Packing Type
                                                           OR (flv.attribute4 IS NOT NULL AND oha.attribute16 = flv.attribute4))
                   AND oha.order_source_id = p_osid              --Source: EDI
                   AND oha.org_id = p_operating_unit;

        -- Variables Declaration
        v_ou_id   NUMBER := p_operating_unit;
        v_os_id   NUMBER := p_osid;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'EDI_860_EXCLUSION Start');

        FOR r_edi_dtls IN c_edi_excl_dtls
        LOOP
            --To update EDI 860 Exclusion in Header Iface
            BEGIN
                UPDATE apps.oe_headers_iface_all
                   SET error_flag = 'Y', request_id = 0000070, last_update_date = SYSDATE,
                       last_updated_by = gn_batch_user_id
                 WHERE     1 = 1
                       AND orig_sys_document_ref = r_edi_dtls.osdr
                       AND org_id = r_edi_dtls.org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Exp- Failed to update EDI860 Exclusion Header details');
            END;

            --To update EDI 860 Exclusion in Line Iface
            BEGIN
                UPDATE apps.oe_lines_iface_all
                   SET error_flag = 'Y', request_id = 0000070, last_update_date = SYSDATE,
                       last_updated_by = gn_batch_user_id
                 WHERE     1 = 1
                       AND orig_sys_document_ref = r_edi_dtls.osdr
                       AND org_id = r_edi_dtls.org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Exp- Failed to update EDI860 Exclusion Header details');
            END;

            COMMIT;
        END LOOP;

        fnd_file.put_line (fnd_file.LOG, 'EDI_860_EXCLUSION End');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'EXP-MAIN Others in EDI 860 Exclusions : ' || SQLERRM);
    END edi_860_exclusion;

    -- END Changes as per CCR0008488

    -- START Changes as per CCR0009192
    -- To Exclude lines status if any (picked, shipped or invoiced)
    PROCEDURE ord_line_status_chk (p_operating_unit   IN NUMBER,
                                   p_osid             IN NUMBER)
    IS
        -- To fetch Order Lines for Line Status Exclusion
        CURSOR c_line_excl_dtls IS
            SELECT DISTINCT ohia.org_id, ohia.orig_sys_document_ref osdr
              FROM oe_order_headers_all oha, oe_headers_iface_all ohia, oe_order_lines_all ola,
                   wsh_delivery_details wdd, wsh_delivery_assignments wda, wsh_new_deliveries wnd
             WHERE     1 = 1
                   AND oha.orig_sys_document_ref = ohia.orig_sys_document_ref
                   AND oha.org_id = ohia.org_id
                   AND oha.header_id = ola.header_id
                   AND ola.line_id = wdd.source_line_id
                   AND wdd.delivery_detail_id = wda.delivery_detail_id
                   AND wda.delivery_id = wnd.delivery_id
                   AND wdd.source_code = 'OE'
                   AND wdd.released_status IN ('Y', 'C', 'I') --PICKED\SHIPPED\INVOICED
                   AND ohia.operation_code = 'UPDATE'
                   AND ohia.error_flag IS NULL
                   AND ohia.request_id IS NULL
                   AND oha.order_source_id = p_osid              --Source: EDI
                   AND oha.org_id = p_operating_unit;

        -- Variables Declaration
        v_ou_id   NUMBER := p_operating_unit;
        v_os_id   NUMBER := p_osid;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'ORD_LINE_STATUS_CHK Start');

        FOR r_line_excl_dtls IN c_line_excl_dtls
        LOOP
            --To update Order line status exclusion in Header Iface
            BEGIN
                UPDATE apps.oe_headers_iface_all
                   SET error_flag = 'Y', request_id = 0000080, last_update_date = SYSDATE,
                       last_updated_by = gn_batch_user_id
                 WHERE     1 = 1
                       AND orig_sys_document_ref = r_line_excl_dtls.osdr
                       AND org_id = r_line_excl_dtls.org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Exp- Failed to update Header Iface for Line status exclusion');
            END;

            --To update Order Line status exclusion in Line Iface
            BEGIN
                UPDATE apps.oe_lines_iface_all
                   SET error_flag = 'Y', request_id = 0000080, last_update_date = SYSDATE,
                       last_updated_by = gn_batch_user_id
                 WHERE     1 = 1
                       AND orig_sys_document_ref = r_line_excl_dtls.osdr
                       AND org_id = r_line_excl_dtls.org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Exp- Failed to update Line Iface for Line status exclusion');
            END;

            COMMIT;
        END LOOP;

        fnd_file.put_line (fnd_file.LOG, 'ORD_LINE_STATUS_CHK End');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'EXP-MAIN Others in ORD_LINE_STATUS_CHK: ' || SQLERRM);
    END ord_line_status_chk;

    -- END Changes as per CCR0009192

    --Begin:- Added for ver 2.3
    FUNCTION get_vas_code (p_level IN VARCHAR2, p_cust_account_id IN NUMBER, p_site_use_id IN NUMBER
                           , p_inventory_item_id IN NUMBER)
        RETURN VARCHAR2
    IS
        l_vas_code   VARCHAR2 (240) := NULL;
    BEGIN
        IF p_level = 'HEADER'
        THEN
            SELECT SUBSTR (LISTAGG (vas_code, '+') WITHIN GROUP (ORDER BY vas_code), 1, 240)
              INTO l_vas_code
              FROM (SELECT DISTINCT vas_code
                      FROM XXD_ONT_VAS_ASSIGNMENT_DTLS_T
                     WHERE     1 = 1
                           AND cust_account_id = p_cust_account_id
                           AND attribute_level IN ('CUSTOMER'));
        ELSIF p_level = 'LINE'
        THEN
            SELECT SUBSTR (LISTAGG (vas_code, '+') WITHIN GROUP (ORDER BY vas_code), 1, 240)
              INTO l_vas_code
              FROM (SELECT vas_code
                      FROM XXD_ONT_VAS_ASSIGNMENT_DTLS_T a, xxd_common_items_v b
                     WHERE     a.attribute_level = 'STYLE'
                           AND b.organization_id = gn_master_org_id
                           AND b.inventory_item_id = p_inventory_item_id
                           AND b.style_NUMBER = a.ATTRIBUTE_VALUE
                           AND cust_account_id = p_cust_account_id --- for style
                    UNION
                    SELECT vas_code
                      FROM XXD_ONT_VAS_ASSIGNMENT_DTLS_T a, xxd_common_items_v b
                     WHERE     a.attribute_level = 'STYLE_COLOR'
                           AND b.organization_id = gn_master_org_id
                           AND b.inventory_item_id = p_inventory_item_id
                           AND a.ATTRIBUTE_VALUE =
                               b.style_NUMBER || '-' || b.color_code
                           AND cust_account_id = p_cust_account_id --- style color
                    UNION
                    SELECT vas_code
                      FROM XXD_ONT_VAS_ASSIGNMENT_DTLS_T a, hz_cust_site_uses_all b
                     WHERE     1 = 1
                           AND cust_account_id = p_cust_account_id
                           AND b.site_use_id = p_site_use_id
                           AND b.cust_acct_site_id = a.attribute_value
                           AND attribute_level IN ('SITE')
                    -- Start Added for CCR0010028
                    UNION
                    SELECT a.vas_code
                      FROM xxd_ont_vas_assignment_dtls_t a, hz_cust_site_uses_all b, xxd_common_items_v c
                     WHERE     a.attribute_level =
                               'SITE-MASTERCLASS-SUBCLASS'
                           AND c.organization_id = gn_master_org_id
                           AND c.inventory_item_id = p_inventory_item_id
                           AND a.cust_account_id = p_cust_account_id
                           AND a.attribute_value = p_site_use_id
                           AND a.attribute_value = b.site_use_id
                           AND (NVL (a.attribute1, '1') = NVL (c.style_NUMBER, '1') OR NVL (a.attribute2, '1') = NVL (c.master_class, '1') OR NVL (a.attribute4, '1') = NVL (c.department, '1')));
        -- End Added for CCR0010028
        END IF;

        RETURN l_vas_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN l_vas_code;
    END get_vas_code;

    --End:- Added for ver 2.3

    --------------------------------------------------------------------
    -- Procdure to validate for any EDI : 860 mix operation (Insert and Update)
    -- Put an EDI order header on hold if mutiple operation on iface lines on same EDI 860 order
    --------------------------------------------------------------------

    PROCEDURE ord_header_hold_chk (p_operating_unit   IN NUMBER,
                                   p_osid             IN NUMBER)
    IS
        ------------------------------------------------------
        -- Declaring the variables and local to the procedure
        ------------------------------------------------------
        v_ou_id                  NUMBER := p_operating_unit;
        v_os_id                  NUMBER := p_osid;
        v_order_type_id          NUMBER := 0;
        v_order_type             oe_transaction_types_tl.name%TYPE;
        ln_hold_id               NUMBER;
        lv_release_reason_code   VARCHAR2 (1000);
        lv_release_comment       VARCHAR2 (1000);

        -------------------------------------------------------
        -- Cursor to get mixed operation orders for HOLD -- as part added for 2.8
        -------------------------------------------------------
        CURSOR cur_get_mix_opr (cn_hold_id NUMBER)
        IS
            SELECT DISTINCT ooha.header_id
              FROM apps.oe_headers_iface_all ooh, apps.oe_lines_iface_all ool, apps.oe_order_headers_all ooha,
                   apps.oe_order_lines_all oola
             WHERE     ooh.org_id = v_ou_id
                   AND ooh.order_source_id = v_os_id
                   AND ooh.error_flag IS NULL
                   AND ooh.request_id IS NULL
                   AND ooh.operation_code = 'UPDATE'
                   AND ool.operation_code = 'UPDATE'
                   AND EXISTS
                           (SELECT 1
                              FROM apps.oe_lines_iface_all ool1
                             WHERE     ool1.orig_sys_document_ref =
                                       ool.orig_sys_document_ref
                                   AND operation_code = 'INSERT')
                   AND ooh.orig_sys_document_ref = ooha.orig_sys_document_ref
                   AND ool.orig_sys_document_ref = ooha.orig_sys_document_ref
                   AND ooh.error_flag IS NULL
                   AND ooh.request_id IS NULL
                   AND ooha.header_id = oola.header_id
                   AND oola.line_category_code = 'ORDER'
                   AND oola.open_flag = 'Y'
                   AND NOT EXISTS
                           (SELECT 1
                              FROM oe_order_holds_all holds, oe_hold_sources_all ohsa, oe_hold_definitions ohd
                             WHERE     holds.hold_source_id =
                                       ohsa.hold_source_id
                                   AND ohsa.hold_id = ohd.hold_id
                                   AND holds.header_id = ooha.header_id
                                   AND holds.released_flag = 'N'
                                   AND ohsa.released_flag = 'N'
                                   AND ohsa.hold_id = cn_hold_id);
    ---------------------------
    --Begining of the procedure
    ---------------------------
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'ord_header_hold_chk Start');
        fnd_file.put_line (fnd_file.output,
                           'List Of Orders which having mutiple ');
        fnd_file.put_line (
            fnd_file.output,
            '--------------------------------------------------------------------');

        --Start as part of 2.8
        SELECT hold_id
          INTO ln_hold_id
          FROM oe_hold_definitions
         WHERE name = 'Deckers EDI 860 Hold';

        ------------------------------------------
        ---860 cusror to call hold proc
        ------------------------------------------

        lv_release_comment   :=
            'EDI 860 HEADER HOLD , REQ ID: ' || gn_request_id;

        FOR rec_get_mix_opr IN cur_get_mix_opr (ln_hold_id)
        LOOP
            fnd_file.put_line (
                fnd_file.LOG,
                'Inside Hold Cursor Header id' || rec_get_mix_opr.header_id);
            xx_apply_release_hold ('HOLD',
                                   ln_hold_id,
                                   rec_get_mix_opr.header_id,
                                   lv_release_reason_code,
                                   lv_release_comment);
        END LOOP;

        --End as part of 2.8

        fnd_file.put_line (fnd_file.LOG, 'ord_header_hold_chk End');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'MAIN Others Exception in ord_header_hold_chk = ' || SQLERRM);
    END ord_header_hold_chk;
-- Start of changes By Siva Boothathan for CCR :CCR0006663
BEGIN
    SELECT organization_id
      INTO gn_master_org_id
      FROM mtl_parameters
     WHERE organization_code = 'MST';

    SELECT user_id
      INTO gn_batch_user_id
      FROM fnd_user
     WHERE user_name = 'BATCH.O2F';
EXCEPTION
    WHEN OTHERS
    THEN
        gn_master_org_id   := -1;
        gn_batch_user_id   := 0;
-- End of changes By Siva Boothathan for CCR :CCR0006663
END xxdo_sales_order_validation;
/
