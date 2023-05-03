--
-- XXDO_BK_BSA_CREATE  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:13 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_BK_BSA_CREATE"
AS
    /***************************************************************************************************************************************
        file name    : XXDO_BK_BSA_CREATE.pkb
        created on   : 24-FEB-2015
        created by   : INFOSYS
        purpose      : package specification used for the following
                               1. To create the sales agreement from a Belk BK File of EDI850
                               2. Return the sales agreement number and sales agreement line number
      **************************************************************************************************************************************
       Modification history:
      **************************************************************************************************************************************


          Version        Date        Author           Description
          ---------  ----------  ---------------  ------------------------------------
          1.0         24-FEB-2015     INFOSYS       1.Created
          1.1         01-APR-2015     INFOSYS       2.Modified to address issues from SIT testing.
          1.2         18-MAY-2015     INFOSYS       3.Modified to populate BRAND on Blanket header DFF(Attribute6).
           1.3         26-May-2015     INFOSYS       4.updated the responsibility to "Deckers Order Management User - US"
           1.4         29-MAY-2015     INFOSYS       5.Included Customer PO check in the BSA validation.
           1.5         11-SEP-2015     INFOSYS       6.Modified to remove the derivation of ship-from-warehouse.
           1.6         18-SEP-2015     INFOSYS       7.Modified for QC 3020 in UAT2 testing.
           1.6         3-JAN-2017     Mithun Mathew  8.Modified for QC 3020 in CCR0005785.
     ***************************************************************************************************************************************
     ***************************************************************************************************************************************/
    --global variables declaration
    g_cust_acct_id      HZ_CUST_ACCOUNTS.cust_account_id%TYPE := 0;
    g_org_id            hr_operating_units.organization_id%TYPE := 0;
    g_brand             HZ_CUST_ACCOUNTS.attribute1%TYPE := NULL;
    g_hdr_db_vw_name    VARCHAR2 (30) := 'OE_AK_ORDER_HEADERS_V';
    g_line_db_vw_name   VARCHAR2 (30) := 'OE_AK_ORDER_LINES_V';
    g_bsa_type_name     OE_TRANSACTION_TYPES_VL.name%TYPE
                            := 'DO Sales Agreement';
    g_bsa_type_id       OE_TRANSACTION_TYPES_VL.TRANSACTION_TYPE_ID%TYPE := 0;
    g_price_list_id     OE_PRICE_LISTS_V.price_list_id%TYPE := NULL;
    g_AGREEMENT_ID      OE_AGREEMENTS_V.agreement_id%TYPE := 0;
    g_class_code        xxd_default_pricelist_matrix.customer_class%TYPE
                            := NULL;
    g_requested_date    VARCHAR2 (50) := NULL;
    g_ordered_date      VARCHAR2 (50) := NULL;
    g_cust_po_number    po_headers_all.segment1%TYPE := NULL;
    g_pkg_name          VARCHAR2 (150) := 'XXDO_BK_BSA_CREATE';
    g_err_num           NUMBER := 0;

    gn_user_id          fnd_user.user_id%TYPE := NULL;
    gn_resp_id          fnd_responsibility_vl.responsibility_id%TYPE := NULL;
    gn_resp_appl_id     fnd_responsibility_vl.application_id%TYPE := NULL;
    gn_batch_user       fnd_user.user_name%TYPE := 'BATCH';
    gn_ord_mngt_resp    fnd_responsibility_vl.responsibility_name%TYPE
                            := 'Deckers Order Management User - US';

    -- START : Added for 1.6.
    PROCEDURE xxdo_apps_initialize
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        mo_global.init ('ONT');
        mo_global.set_policy_context ('S', g_org_id);

        fnd_global.apps_initialize (gn_user_id, gn_resp_id, gn_resp_appl_id);
        COMMIT;
    END xxdo_apps_initialize;

    -- END : Added for 1.6.


    -- ***************************************************************************
    -- Procedure :  bsa_create
    -- Description:Main procedure which calls the other procedures to derive default values and call API to create BSA
    -- ***************************************************************************
    PROCEDURE bsa_create (
        p_cust_name         IN     VARCHAR2,
        p_brand             IN     VARCHAR2,
        p_org_id            IN     NUMBER,
        p_cust_po_number    IN     VARCHAR2,
        p_end_date_active   IN     VARCHAR2 DEFAULT NULL,
        p_bsa_name          IN     VARCHAR2 DEFAULT NULL,
        p_requested_date    IN     VARCHAR2 DEFAULT TO_CHAR (TRUNC (SYSDATE),
                                                             'DD-MON-RRRR'),
        p_ordered_date      IN     VARCHAR2 DEFAULT TO_CHAR (TRUNC (SYSDATE),
                                                             'DD-MON-RRRR'),
        p_line_tbl          IN     OE_BLANKET_PUB.line_tbl_Type,
        p_ret_code             OUT NUMBER,
        p_err_msg              OUT VARCHAR2,
        p_bsa_number           OUT oe_blanket_headers_all.order_number%TYPE)
    IS
        --API Input variables

        l_hdr_rec                   OE_Blanket_PUB.header_Rec_type;
        l_hdr_val_rec               OE_Blanket_PUB.header_val_Rec_type;

        l_line_tbl                  OE_Blanket_PUB.line_tbl_Type;
        l_line_tbl_rec              OE_Blanket_PUB.line_tbl_Type;
        l_line_val_tbl              OE_Blanket_PUB.line_Val_tbl_Type;
        --      l_line_rec                  OE_Blanket_PUB.line_rec_Type;
        --      l_line_val_rec              OE_Blanket_PUB.line_val_rec_Type;

        l_control_rec               OE_Blanket_PUB.Control_rec_type;


        --API output variables

        x_line_tbl                  OE_Blanket_PUB.line_tbl_Type;
        x_header_rec                OE_Blanket_PUB.header_Rec_type;
        x_msg_count                 NUMBER;
        x_msg_data                  VARCHAR2 (2000);
        x_return_status             VARCHAR2 (30);

        --API Incremental variables
        i                           NUMBER;
        j                           NUMBER;


        -- Default value variables
        l_shipping_method_code      OE_AK_SHIP_TO_ORGS_V.shipping_method_code%TYPE
            := NULL;
        l_freight_terms_code        OE_AK_SHIP_TO_ORGS_V.freight_terms_code%TYPE
                                        := NULL;
        l_payment_term_id           OE_AGREEMENTS_V.payment_term_id%TYPE := NULL;
        l_price_list_id             OE_AK_ORDER_TYPES_V.price_list_id%TYPE
                                        := NULL;
        l_ship_to_org_id            OE_AK_SOLD_TO_ORGS_V.ship_to_org_id%TYPE
                                        := NULL;
        --      l_ship_from_org_id          OE_AK_SHIP_TO_ORGS_V.ship_from_org_id%TYPE  -- 1.5 .Modified to remove the derivation of ship-from-warehouse.
        --                                     := NULL;
        l_transactional_curr_code   OE_PRICE_LISTS_V.currency_code%TYPE
                                        := NULL;

        l_inventory_item_id         mtl_system_items_b.inventory_item_id%TYPE
                                        := 0;
        l_disp_err_msg              VARCHAR2 (4000) := NULL;
        l_sales_ship_id             HZ_CUST_SITE_USES_ALL.SITE_USE_ID%TYPE
                                        := 0;
        -- OUT Variables declaration
        l_err_msg                   VARCHAR2 (4000) := NULL;
        l_ret_code                  NUMBER := 0;
        l_bsa_number                oe_blanket_headers_all.order_number%TYPE;

        --Other variables
        l_proc_name                 VARCHAR2 (150) := 'BSA_CREATE';
        l_bsa_count                 NUMBER := 0;
        l_end_dt_chk_flag           VARCHAR2 (1) := NULL; -- Added by Lakshmi on 20-MAR-2015
    BEGIN
        -- Assigning values to global variables from parameters
        g_org_id           := p_org_id;
        g_requested_date   := p_requested_date;
        g_ordered_date     := p_ordered_date;
        g_brand            := p_brand;
        g_cust_po_number   := p_cust_po_number;
        l_line_tbl         := p_line_tbl;

        BEGIN
            -- mo_global.set_policy_context ('S', g_org_id); -- Commented for 1.6.

            SELECT user_id
              INTO gn_user_id
              FROM apps.fnd_user
             WHERE user_name = gn_batch_user;

            SELECT responsibility_id, application_id
              INTO gn_resp_id, gn_resp_appl_id
              FROM apps.fnd_responsibility_vl
             WHERE responsibility_name = gn_ord_mngt_resp;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_disp_err_msg   :=
                       'Error while deriving User, Responsibility and Application for APPS Initialize : '
                    || SQLERRM;
                l_err_msg    := l_err_msg || ' - ' || l_disp_err_msg;
                l_ret_code   := 1;
                g_err_num    := g_err_num + 1;
                log_errors_bk (g_err_num, g_pkg_name, l_proc_name,
                               l_disp_err_msg);
        END;


        BEGIN
            --  fnd_global.apps_initialize (gn_user_id, gn_resp_id, gn_resp_appl_id);
            xxdo_apps_initialize;                         -- Modified for 1.6.
        EXCEPTION
            WHEN OTHERS
            THEN
                l_disp_err_msg   :=
                    'Error while calling APPS Initialize : ' || SQLERRM;
                l_err_msg    := l_err_msg || ' - ' || l_disp_err_msg;
                l_ret_code   := 1;
                g_err_num    := g_err_num + 1;
                log_errors_bk (g_err_num, g_pkg_name, l_proc_name,
                               l_disp_err_msg);
        END;


        -- Deleting From The error table
        -- DELETE FROM XXDO.xxdo_bk_bsa_errors; -- Commented for 1.6.

        --   COMMIT; -- Commented, since SOA will use XA data source.

        -- Fetching values to be passed to the BSA API
        -- To Fetch the sold_to_org_id
        BEGIN
            SELECT hca.cust_account_id, hca.customer_class_code
              INTO g_cust_acct_id, g_class_code
              FROM APPS.HZ_CUST_ACCOUNTS hca, hz_parties hp
             WHERE     hca.party_id = hp.party_id
                   AND hp.party_name = p_cust_name
                   AND hca.attribute1 = p_brand
                   AND hp.status = 'A'
                   AND hca.status = 'A';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                l_disp_err_msg   :=
                       'Error While Fetching Cust Account ID For The Customer: '
                    || p_cust_name
                    || ' and brand: '
                    || p_brand
                    || ' '
                    || SQLERRM;

                l_err_msg    := l_err_msg || ' - ' || l_disp_err_msg;

                DBMS_OUTPUT.put_line (l_disp_err_msg);

                l_ret_code   := 1;
                g_err_num    := g_err_num + 1;
                log_errors_bk (g_err_num, g_pkg_name, l_proc_name,
                               l_disp_err_msg);
            WHEN OTHERS
            THEN
                l_disp_err_msg   :=
                       'Error While Fetching Cust Account ID For The Customer: '
                    || p_cust_name
                    || ' '
                    || SQLERRM;

                l_err_msg    := l_err_msg || ' - ' || l_disp_err_msg;

                DBMS_OUTPUT.put_line (l_disp_err_msg);

                l_ret_code   := 1;
                g_err_num    := g_err_num + 1;
                log_errors_bk (g_err_num, g_pkg_name, l_proc_name,
                               l_disp_err_msg);
        END;


        -- To check if there is already an Active sales agreement existing for this customer and org
        /*
        SELECT COUNT (1)                                        --blanket_number
          INTO l_bsa_count
          FROM oe_blanket_headers_all
         WHERE     sold_to_org_id = g_cust_acct_id
               AND flow_status_code = 'ACTIVE'
               AND org_id = g_org_id; */
        -- Modified for 1.1.

        -- START : Modified for 1.1.
        SELECT COUNT (1)
          INTO l_bsa_count
          FROM oe_blanket_headers_all obh, oe_blanket_headers_ext obhe
         WHERE     obh.order_number = obhe.order_number
               AND sold_to_org_id = g_cust_acct_id
               AND flow_status_code = 'ACTIVE'
               AND org_id = g_org_id
               AND cust_po_number = g_cust_po_number         -- Added for 1.4.
               AND SYSDATE BETWEEN NVL (obhe.start_date_active, SYSDATE)
                               AND NVL (obhe.end_date_active, SYSDATE);

        -- END : Modified for 1.1.

        IF l_bsa_count = 0
        THEN
            -- To Fetch the Order Type ID (Sales Agreement Type ID)
            BEGIN
                SELECT TRANSACTION_TYPE_ID
                  INTO g_bsa_type_id
                  FROM APPS.OE_TRANSACTION_TYPES_TL
                 WHERE NAME = g_bsa_type_name AND LANGUAGE = USERENV ('LANG');
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_disp_err_msg   :=
                           'Sales Agreement Type '
                        || g_bsa_type_name
                        || 'Does Not Exist';
                    l_err_msg    := l_err_msg || ' - ' || l_disp_err_msg;

                    DBMS_OUTPUT.put_line (l_disp_err_msg);

                    l_ret_code   := 1;
                    g_err_num    := g_err_num + 1;
                    log_errors_bk (g_err_num, g_pkg_name, l_proc_name,
                                   l_disp_err_msg);
                WHEN OTHERS
                THEN
                    l_disp_err_msg   :=
                           'Error While Fetching BSA Type ID For The Sales Agreement Type: '
                        || g_bsa_type_name
                        || SQLERRM;
                    l_err_msg    := l_err_msg || ' - ' || l_disp_err_msg;

                    DBMS_OUTPUT.put_line (l_disp_err_msg);

                    l_ret_code   := 1;
                    g_err_num    := g_err_num + 1;
                    log_errors_bk (g_err_num, g_pkg_name, l_proc_name,
                                   l_disp_err_msg);
            END;

            -- Calling procedure to fetch default values

            get_def_rul_seq ('PRICE_LIST_ID', l_price_list_id);

            IF l_price_list_id IS NULL
            THEN
                l_disp_err_msg   :=
                    'Default Value For Price_list_id Not Found';
                l_err_msg    := l_err_msg || ' - ' || l_disp_err_msg;

                DBMS_OUTPUT.put_line (l_disp_err_msg);

                l_ret_code   := 1;
                g_err_num    := g_err_num + 1;
                log_errors_bk (g_err_num, g_pkg_name, l_proc_name,
                               l_disp_err_msg);
            END IF;

            g_price_list_id   := l_price_list_id; -- To be used to derive other fields by passing price_list_id

            DBMS_OUTPUT.put_line ('l_price_list_id: ' || l_price_list_id);

            get_def_rul_seq ('SHIPPING_METHOD_CODE', l_shipping_method_code);

            IF l_shipping_method_code IS NULL
            THEN
                l_disp_err_msg   :=
                    'Default Value For Shipping_method_code Not Found';
                l_err_msg    := l_err_msg || ' - ' || l_disp_err_msg;

                DBMS_OUTPUT.put_line (l_disp_err_msg);

                l_ret_code   := 1;
                g_err_num    := g_err_num + 1;
                log_errors_bk (g_err_num, g_pkg_name, l_proc_name,
                               l_disp_err_msg);
            END IF;

            DBMS_OUTPUT.put_line (
                'l_shipping_method_code: ' || l_shipping_method_code);

            get_def_rul_seq ('FREIGHT_TERMS_CODE', l_freight_terms_code);

            IF l_freight_terms_code IS NULL
            THEN
                l_disp_err_msg   :=
                    'Default Value For Freight_terms_code Not Found';
                l_err_msg    := l_err_msg || ' - ' || l_disp_err_msg;

                DBMS_OUTPUT.put_line (l_disp_err_msg);

                l_ret_code   := 1;
                g_err_num    := g_err_num + 1;
                log_errors_bk (g_err_num, g_pkg_name, l_proc_name,
                               l_disp_err_msg);
            END IF;

            DBMS_OUTPUT.put_line (
                'l_freight_terms_code: ' || l_freight_terms_code);

            get_def_rul_seq ('PAYMENT_TERM_ID', l_payment_term_id);

            IF l_payment_term_id IS NULL
            THEN
                l_disp_err_msg   :=
                    'Default Value For Payment_term_id Not Found';
                l_err_msg    := l_err_msg || ' - ' || l_disp_err_msg;

                DBMS_OUTPUT.put_line (l_disp_err_msg);

                l_ret_code   := 1;
                g_err_num    := g_err_num + 1;
                log_errors_bk (g_err_num, g_pkg_name, l_proc_name,
                               l_disp_err_msg);
            END IF;

            DBMS_OUTPUT.put_line ('l_payment_term_id: ' || l_payment_term_id);

            /*   get_def_rul_seq ('SHIP_TO_ORG_ID', l_ship_to_org_id);

               IF l_ship_to_org_id IS NULL
               THEN
                  l_disp_err_msg := 'Default Value For Ship_to_org_id Not Found';
                  l_err_msg := l_err_msg || ' - ' || l_disp_err_msg;

                  DBMS_OUTPUT.put_line (l_disp_err_msg);

                  l_ret_code := 1;
               END IF;

               DBMS_OUTPUT.put_line ('l_ship_to_org_id: ' || l_ship_to_org_id); */

            /*  get_def_rul_seq ('SHIP_FROM_ORG_ID', l_ship_from_org_id); -- Warehouse

              IF l_ship_from_org_id IS NULL
              THEN
                 l_disp_err_msg := 'Default Value For Ship_from_org_id Not Found';
                 l_err_msg := l_err_msg || ' - ' || l_disp_err_msg;

                 DBMS_OUTPUT.put_line (l_disp_err_msg);

                 l_ret_code := 1;
                 g_err_num := g_err_num + 1;
                 log_errors_bk (g_err_num,
                                g_pkg_name,
                                l_proc_name,
                                l_disp_err_msg);
              END IF;

              DBMS_OUTPUT.put_line ('l_ship_from_org_id: ' || l_ship_from_org_id); */
            -- 1.5 .Modified to remove the derivation of ship-from-warehouse.

            get_def_rul_seq ('TRANSACTIONAL_CURR_CODE',
                             l_transactional_curr_code);

            IF l_transactional_curr_code IS NULL
            THEN
                l_disp_err_msg   :=
                    'Default Value For Transactional_curr_code Not Found';
                l_err_msg    := l_err_msg || ' - ' || l_disp_err_msg;

                DBMS_OUTPUT.put_line (l_disp_err_msg);

                l_ret_code   := 1;
                g_err_num    := g_err_num + 1;
                log_errors_bk (g_err_num, g_pkg_name, l_proc_name,
                               l_disp_err_msg);
            END IF;

            DBMS_OUTPUT.put_line (
                'l_transactional_curr_code: ' || l_transactional_curr_code);


            -- Added by Lakshmi on 20-MAR-2015
            -- To check whether the end_date_active is greater than or equal to sysdate
            IF p_end_date_active IS NOT NULL
            THEN
                BEGIN
                    IF (TO_DATE (p_end_date_active, 'RRRR-MM-DD') >= SYSDATE)
                    THEN
                        l_end_dt_chk_flag   := 'Y';
                    ELSE
                        l_end_dt_chk_flag   := 'N';
                    END IF;

                    IF l_end_dt_chk_flag = 'N'
                    THEN
                        l_disp_err_msg   :=
                            'End-Date-Active Must Be Greater Than Or Equal To Activation Date And Current Date';
                        l_err_msg    := l_err_msg || ' - ' || l_disp_err_msg;

                        DBMS_OUTPUT.put_line (l_disp_err_msg);

                        l_ret_code   := 1;
                        g_err_num    := g_err_num + 1;
                        log_errors_bk (g_err_num, g_pkg_name, l_proc_name,
                                       l_disp_err_msg);
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_disp_err_msg   :=
                               'Error While Checking the End date active value: '
                            || SQLERRM;
                        l_err_msg    := l_err_msg || ' - ' || l_disp_err_msg;

                        DBMS_OUTPUT.put_line (l_disp_err_msg);

                        l_ret_code   := 1;
                        g_err_num    := g_err_num + 1;
                        log_errors_bk (g_err_num, g_pkg_name, l_proc_name,
                                       l_disp_err_msg);
                END;
            END IF;

            DBMS_OUTPUT.put_line ('Calling API to create BSA..');

            BEGIN
                -- Fetching Customer Ship-to site use ID to derive salesrep id
                l_sales_ship_id   := get_site_use_id ('SHIP_TO');

                -- setting OM debug level and writing debug info to a debug file   oe_debug_pub.setdebuglevel(5);    oe_debug_pub.add('Enter create BSA ',1);    dbms_output.put_line('The debug file is :'||OE_DEBUG_PUB.G_DIR||'/'||OE_DEBUG_PUB.G_FILE);
                -- MO_GLOBAL.INIT ('ONT');                                    -- MOAC -- Commented for 1.6

                FOR j IN 1 .. 1                                 -- Header Loop
                LOOP
                    l_hdr_rec                           := OE_Blanket_PUB.G_MISS_HEADER_REC; -- Consider header record as missing
                    l_hdr_val_rec                       := OE_Blanket_PUB.G_MISS_HEADER_VAL_REC; -- Consider header val record as missing
                    l_hdr_rec.operation                 := OE_Globals.G_OPR_CREATE; -- Header Operation

                    -- MAIN tab
                    l_hdr_rec.sold_to_org_id            := g_cust_acct_id; -- cust_acct_id
                    l_hdr_rec.order_type_id             := g_bsa_type_id; -- BSA Type ID
                    l_hdr_rec.start_date_active         := SYSDATE;
                    l_hdr_rec.end_date_active           :=
                        TO_DATE (p_end_date_active, 'RRRR-MM-DD'); --Added by Lakshmi on 20-MAR-2015
                    l_hdr_rec.cust_po_number            := g_cust_po_number;
                    --               l_hdr_rec.ship_from_org_id := l_ship_from_org_id;  -- Warehouse  -- 1.5 .Modified to remove the derivation of ship-from-warehouse.
                    -- Shipping tab
                    --            l_hdr_rec.ship_to_org_id := l_ship_to_org_id;    -- Ship to org id  -- Not mandatory
                    l_hdr_rec.freight_terms_code        := l_freight_terms_code; -- Freight terms code
                    l_hdr_rec.shipping_method_code      :=
                        l_shipping_method_code;        -- Shipping method code
                    --Accounting tab
                    l_hdr_rec.transactional_curr_code   :=
                        l_transactional_curr_code; -- Transactional currency code
                    l_hdr_rec.payment_term_id           := l_payment_term_id; -- Payment term NET 30
                    --Pricing tab
                    l_hdr_rec.price_list_id             := l_price_list_id; --  price_list_id for corporate price list
                    l_hdr_rec.enforce_price_list_flag   := 'N'; -- will enforce price list on the releases.
                    --Fulfillment tab
                    l_hdr_rec.blanket_min_amount        := 1;
                    l_hdr_rec.blanket_max_amount        := 0;

                    l_hdr_rec.override_amount_flag      := 'Y'; -- Added for 1.1.

                    l_hdr_rec.attribute6                := g_brand; -- Added for 1.2.

                    FOR i IN l_line_tbl.FIRST .. l_line_tbl.LAST -- Lines Loop
                    LOOP
                        l_line_tbl_rec (i)   := l_line_tbl (i);

                        l_line_tbl_rec (i).OVERRIDE_BLANKET_CONTROLS_FLAG   :=
                            'Y';                             -- Added for 1.1.
                        l_line_tbl_rec (i).OVERRIDE_RELEASE_CONTROLS_FLAG   :=
                            'Y';                             -- Added for 1.1.

                        IF (l_line_tbl_rec (i).inventory_item_id IS NOT NULL AND g_org_id IS NOT NULL AND g_cust_acct_id IS NOT NULL AND l_sales_ship_id IS NOT NULL)
                        THEN
                            l_line_tbl_rec (i).salesrep_id   :=
                                get_sales_rep_id (l_line_tbl_rec (i).inventory_item_id, g_org_id, g_cust_acct_id
                                                  , l_sales_ship_id);
                        END IF;

                        l_line_val_tbl (i)   :=
                            OE_Blanket_PUB.G_MISS_BLANKET_LINE_VAL_REC;
                        l_hdr_rec.blanket_max_amount   :=
                              l_hdr_rec.blanket_max_amount
                            + l_line_tbl_rec (i).blanket_max_amount;
                    END LOOP;                                    -- Lines Loop

                    oe_debug_pub.add ('Before calling Process Blanket API',
                                      1);
                    oe_msg_pub.initialize;

                    DBMS_OUTPUT.put_line ('Calling standard API..');

                    OE_Blanket_PUB.Process_Blanket (
                        p_org_id               => g_org_id,          -- org_id
                        p_operating_unit       => NULL,
                        p_api_version_number   => 1.0,
                        x_return_status        => x_return_status,
                        x_msg_count            => x_msg_count,
                        x_msg_data             => x_msg_data,
                        p_header_rec           => l_hdr_rec,
                        p_header_val_rec       => l_hdr_val_rec,
                        p_line_tbl             => l_line_tbl_rec,
                        p_line_val_tbl         => l_line_val_tbl,
                        p_control_rec          => l_control_rec,
                        x_header_rec           => x_header_rec,
                        x_line_tbl             => x_line_tbl);

                    oe_debug_pub.add (
                        'Number of OE messages :' || x_msg_count,
                        1);

                    l_disp_err_msg                      :=
                           'API Return Status :'
                        || x_return_status
                        || ' Sales Agreement Number :'
                        || x_header_rec.order_number
                        || '(Header ID : '
                        || x_header_rec.header_id
                        || ')';

                    g_err_num                           := g_err_num + 1;
                    log_errors_bk (g_err_num, g_pkg_name, l_proc_name,
                                   l_disp_err_msg);

                    FOR k IN 1 .. x_msg_count
                    LOOP
                        x_msg_data   :=
                            oe_msg_pub.get (p_msg_index => k, p_encoded => 'F');
                        DBMS_OUTPUT.put_line ('Message :' || x_msg_data);
                        oe_debug_pub.add (SUBSTR (x_msg_data, 1, 255));
                        oe_debug_pub.add (
                            SUBSTR (x_msg_data, 255, LENGTH (x_msg_data)));

                        --                  l_err_msg := l_err_msg || ' - ' || x_msg_data;
                        IF x_return_status <> FND_API.G_RET_STS_SUCCESS
                        THEN
                            g_err_num    := g_err_num + 1;
                            log_errors_bk (g_err_num, g_pkg_name, l_proc_name || ' :API-MESSAGES'
                                           , x_msg_data);
                            l_ret_code   := 1;

                            IF UPPER (x_msg_data) NOT LIKE
                                   'BOTH VALUE AND ID COLUMNS%' -- Added by Lakshmi BTDEV Team on 17-MAR-2015
                            THEN
                                l_err_msg   :=
                                    l_err_msg || ' - ' || x_msg_data;
                            END IF;
                        END IF;
                    END LOOP;                                 -- Messages Loop


                    IF x_return_status <> FND_API.G_RET_STS_SUCCESS
                    THEN
                        oe_debug_pub.add ('Error in process blanket ', 1);
                        l_disp_err_msg              :=
                            'Error in Process blanket, Check the debug log file ';
                        DBMS_OUTPUT.put_line (l_disp_err_msg);

                        g_err_num                   := g_err_num + 1;
                        log_errors_bk (g_err_num, g_pkg_name, l_proc_name,
                                       l_disp_err_msg);
                        x_header_rec.order_number   := NULL; -- Added by Lakshmi BTDEV Team on 17-MAR-2015
                        x_header_rec.header_id      := NULL; -- Added by Lakshmi BTDEV Team on 17-MAR-2015
                        ROLLBACK;
                        l_ret_code                  := 1;
                        l_err_msg                   :=
                            l_err_msg || ' - ' || l_disp_err_msg;
                    ELSE
                        DBMS_OUTPUT.put_line (
                               'New Sales Agreement Number is :'
                            || x_header_rec.order_number
                            || '(Header ID : '
                            || x_header_rec.header_id
                            || ')');
                        oe_debug_pub.add (
                            'Line ID :' || x_line_tbl (1).line_id,
                            1);
                        oe_debug_pub.add (
                            'Header ID :' || x_header_rec.header_id,
                            1);
                        oe_debug_pub.add (
                            'Order number :' || x_header_rec.order_number,
                            1);
                        oe_debug_pub.add (
                            'Sold To :' || x_header_rec.sold_to_org_id,
                            1);
                        oe_debug_pub.add (
                            'Invoice To :' || x_header_rec.invoice_to_org_id,
                            1);
                        oe_debug_pub.add (
                            'Ship To :' || x_header_rec.ship_to_org_id,
                            1);
                    END IF;
                END LOOP;                                       -- Header loop

                IF (x_header_rec.header_id IS NOT NULL AND x_return_status = FND_API.G_RET_STS_SUCCESS) -- Modified by Lakshmi BTDEV Team on 17-MAR-2015
                THEN
                    WF_ENGINE.completeactivity ('OEBH', TO_CHAR (x_header_rec.header_id), 'BLANKET_SUBMIT_DRAFT_ELIGIBLE'
                                                , WF_ENGINE.eng_null);
                    l_err_msg    :=
                        l_err_msg || ' - ' || 'BSA Created Successfully'; -- Added by Lakshmi BTDEV Team on 17-MAR-2015
                    l_ret_code   := 0; -- Added by Lakshmi BTDEV Team on 17-MAR-2015
                END IF;
            --   COMMIT;  -- Commented, since SOA will use XA data source.

            END;

            -- Assigning values to out variables
            p_bsa_number      := x_header_rec.order_number;
            p_ret_code        := l_ret_code;
            p_err_msg         := l_err_msg;
        ELSE                                          -- IF BSA Already exists
            p_bsa_number   := NULL;
            p_ret_code     := 1;
            p_err_msg      :=
                   'Blanket Sales Agreement already exists for the Customer: '
                || p_cust_name
                || ' Org ID: '
                || g_org_id
                || ' and Cust-PO-Number: '
                || g_cust_po_number; -- Added by Lakshmi BTDEV Team on 01-Jun-2015 for 1.4
            DBMS_OUTPUT.PUT_LINE (p_err_msg);
            g_err_num      := g_err_num + 1;
            log_errors_bk (g_err_num, g_pkg_name, l_proc_name,
                           p_err_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_disp_err_msg   :=
                   'Error in procedure XXDO_BK_BSA_CREATE.bsa_create: '
                || SQLERRM;
            DBMS_OUTPUT.PUT_LINE (l_disp_err_msg);
            g_err_num      := g_err_num + 1;
            log_errors_bk (g_err_num, g_pkg_name, l_proc_name,
                           l_disp_err_msg);
            p_bsa_number   := NULL;
            p_ret_code     := 2;
            p_err_msg      := l_err_msg || ' - ' || l_disp_err_msg;
    END bsa_create;

    -- ***************************************************************************
    -- Procedure :  get_def_rul_seq
    -- Description: Procedure to fetch the defaulting rule sequence from the setup
    -- ***************************************************************************
    PROCEDURE get_def_rul_seq (p_attr_name_in   IN     VARCHAR2,
                               p_attr_val_out      OUT VARCHAR2)
    IS
        l_attr_val_out   VARCHAR2 (1000) := NULL;
        l_disp_err_msg   VARCHAR2 (4000) := NULL;
        l_proc_name      VARCHAR2 (150) := 'GET_DEF_RUL_SEQ';

        -- Cursor to fetch the source details sequentially based on defaulting order
        CURSOR c_def_src_details (p_database_object_name   VARCHAR2,
                                  p_attribute_code         VARCHAR2)
        IS
              SELECT src_type, SRC_API_PKG, SRC_API_FN,
                     src_profile_option, src_constant_value, src_system_variable_expr,
                     src_database_object_name, src_attribute_code
                FROM OE_DEF_ATTR_CONDNS_V odacv, OE_DEF_ATTR_RULES_V odarv
               WHERE     odacv.attr_def_condition_id =
                         odarv.attr_def_condition_id
                     AND odacv.database_object_name =
                         odarv.database_object_name
                     AND odacv.enabled_flag = 'Y'
                     AND odacv.condition_id = '0'                    -- Always
                     AND odarv.DATABASE_OBJECT_NAME = p_database_object_name
                     AND odacv.attribute_code = p_attribute_code
            ORDER BY odarv.sequence_no;
    BEGIN
        -- Customer PO Number --BEG03

        -- End Date active (optional) -- SO Date (BEG05)

        -- Sales Agreement Name

        ------------------------------------------
        -- HEADER RECORD --
        ------------------------------------------

        -- To Fetch the Default Values

        FOR r_def_src_details
            IN c_def_src_details (g_hdr_db_vw_name, p_attr_name_in)
        LOOP
            IF p_attr_name_in = 'SHIPPING_METHOD_CODE'
            THEN
                get_attr_val (p_src_type => r_def_src_details.src_type, p_src_database_object_name => r_def_src_details.src_database_object_name, p_attribute_code => p_attr_name_in
                              , p_attr_val => l_attr_val_out);

                p_attr_val_out   := l_attr_val_out;
                EXIT WHEN l_attr_val_out IS NOT NULL;
            END IF;

            IF p_attr_name_in = 'FREIGHT_TERMS_CODE'
            THEN
                get_attr_val (p_src_type => r_def_src_details.src_type, p_src_database_object_name => r_def_src_details.src_database_object_name, p_attribute_code => p_attr_name_in
                              , p_attr_val => l_attr_val_out);

                p_attr_val_out   := l_attr_val_out;
                EXIT WHEN l_attr_val_out IS NOT NULL;
            END IF;

            IF p_attr_name_in = 'PAYMENT_TERM_ID'
            THEN
                get_attr_val (p_src_type => r_def_src_details.src_type, p_src_database_object_name => r_def_src_details.src_database_object_name, p_attribute_code => p_attr_name_in
                              , p_attr_val => l_attr_val_out);

                p_attr_val_out   := l_attr_val_out;
                EXIT WHEN l_attr_val_out IS NOT NULL;
            END IF;

            IF p_attr_name_in = 'PRICE_LIST_ID'
            THEN
                get_attr_val (
                    p_src_type         => r_def_src_details.src_type,
                    p_src_database_object_name   =>
                        r_def_src_details.src_database_object_name,
                    p_attribute_code   => p_attr_name_in,
                    p_SRC_API_PKG      => r_def_src_details.SRC_API_PKG,
                    p_src_api_fn       => r_def_src_details.src_api_fn,
                    p_attr_val         => l_attr_val_out);

                p_attr_val_out   := l_attr_val_out;
                EXIT WHEN l_attr_val_out IS NOT NULL;
            END IF;

            IF p_attr_name_in = 'TRANSACTIONAL_CURR_CODE'
            THEN
                get_attr_val (
                    p_src_type         => r_def_src_details.src_type,
                    p_src_database_object_name   =>
                        r_def_src_details.src_database_object_name,
                    p_attribute_code   => p_attr_name_in,
                    p_SRC_API_PKG      => r_def_src_details.SRC_API_PKG,
                    p_src_api_fn       => r_def_src_details.src_api_fn,
                    p_attr_val         => l_attr_val_out);

                p_attr_val_out   := l_attr_val_out;
                EXIT WHEN l_attr_val_out IS NOT NULL;
            END IF;
        /*IF p_attr_name_in = 'SHIP_TO_ORG_ID'
        THEN
           get_attr_val (
              p_src_type                   => r_def_src_details.src_type,
              p_src_database_object_name   => r_def_src_details.src_database_object_name,
              p_attribute_code             => p_attr_name_in,
              p_SRC_API_PKG                => r_def_src_details.src_api_pkg,
              p_src_api_fn                 => r_def_src_details.src_api_fn,
              p_attr_val                   => l_attr_val_out);

           p_attr_val_out := l_attr_val_out;
           EXIT WHEN l_attr_val_out IS NOT NULL;
        END IF; */

        /*   IF p_attr_name_in = 'SHIP_FROM_ORG_ID'   -- 1.5 .Modified to remove the derivation of ship-from-warehouse.
           THEN
              get_attr_val (
                 p_src_type                   => r_def_src_details.src_type,
                 p_src_database_object_name   => r_def_src_details.src_database_object_name,
                 p_attribute_code             => p_attr_name_in,
                 p_SRC_API_PKG                => r_def_src_details.src_api_pkg,
                 p_src_api_fn                 => r_def_src_details.src_api_fn,
                 p_attr_val                   => l_attr_val_out);

              p_attr_val_out := l_attr_val_out;
              EXIT WHEN l_attr_val_out IS NOT NULL;
           END IF;*/
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_disp_err_msg   :=
                'Error in procedure get_def_rul_seq: ' || SQLERRM;
            DBMS_OUTPUT.put_line (l_disp_err_msg);
            g_err_num   := g_err_num + 1;
            log_errors_bk (g_err_num, g_pkg_name, l_proc_name,
                           l_disp_err_msg);
    END get_def_rul_seq;

    -- ***************************************************************************
    -- Function :  get_site_use_id
    -- Description: Function to fetch the site_use_id
    -- ***************************************************************************
    FUNCTION get_site_use_id (p_site_use_code IN VARCHAR2)
        RETURN NUMBER
    IS
        l_site_use_id    hz_cust_site_uses_all.site_use_id%TYPE := 0;
        l_disp_err_msg   VARCHAR2 (4000) := NULL;
        l_proc_name      VARCHAR2 (150) := 'GET_SITE_USE_ID';
    BEGIN
        /*
        BEGIN
           MO_GLOBAL.SET_POLICY_CONTEXT ('S', g_org_id);
        END;
        */
        -- Commented for 1.6.

        xxdo_apps_initialize;                             -- Modified for 1.6.

        --    COMMIT; -- Commented, since SOA will use XA data source.


        SELECT hcsu.site_use_id
          INTO l_site_use_id
          FROM (SELECT NVL (HCAR.related_cust_account_id, HCA.cust_account_id) related_cust_account_id, HCA.status, Hca.Cust_Account_Id
                  FROM hz_cust_accounts HCA, hz_cust_acct_relate HCAR
                 WHERE     HCA.cust_account_id = HCAR.cust_account_id(+)
                       AND HCAR.status(+) = 'A'
                       AND HCA.cust_account_id = g_cust_acct_id) hca,
               hz_cust_acct_sites hcas,
               hz_cust_site_uses hcsu,
               hz_party_sites party_site,
               hz_locations loc
         WHERE     hca.related_cust_account_id = hcas.cust_account_id
               AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
               AND hcas.party_site_id = party_site.party_site_id
               AND party_site.location_id = loc.location_id
               AND hcsu.site_use_code = p_site_use_code
               AND hcsu.primary_flag = 'Y'
               AND hca.status = 'A'
               AND hcas.status = 'A'
               AND hcsu.status = 'A';

        RETURN l_site_use_id;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            l_disp_err_msg   :=
                   p_site_use_code
                || ' site_use_id for customer id: '
                || g_cust_acct_id
                || ' does not exist for the org_id: '
                || g_org_id;
            DBMS_OUTPUT.put_line (l_disp_err_msg);
            g_err_num   := g_err_num + 1;
            log_errors_bk (g_err_num, g_pkg_name, l_proc_name,
                           l_disp_err_msg);
            RETURN NULL;
        WHEN OTHERS
        THEN
            l_disp_err_msg   :=
                   'Error While Fetching '
                || p_site_use_code
                || ' site_use_id for customer id: '
                || g_cust_acct_id
                || ' for the org_id: '
                || g_org_id
                || ': '
                || SQLERRM;

            DBMS_OUTPUT.put_line (l_disp_err_msg);
            g_err_num   := g_err_num + 1;
            log_errors_bk (g_err_num, g_pkg_name, l_proc_name,
                           l_disp_err_msg);

            RETURN NULL;
    END;

    -- ***************************************************************************
    -- Procedure :  get_attr_val
    -- Description: Procedure to fetch the default values for the fields on BSA
    -- ***************************************************************************
    PROCEDURE get_attr_val (p_src_type IN VARCHAR2, p_SRC_API_PKG IN VARCHAR2 DEFAULT NULL, p_SRC_API_FN IN VARCHAR2 DEFAULT NULL, p_src_profile_option IN VARCHAR2 DEFAULT NULL, p_src_constant_value IN VARCHAR2 DEFAULT NULL, p_src_system_variable_expr IN VARCHAR2 DEFAULT NULL
                            , p_src_database_object_name IN VARCHAR2 DEFAULT NULL, p_attribute_code IN VARCHAR2, p_attr_val OUT VARCHAR2)
    IS
        l_attr_val           VARCHAR2 (1000) := NULL;
        l_rel_rec            OE_DEF_ATTR_RULES_V.src_type%TYPE := 'RELATED_RECORD';
        l_api                OE_DEF_ATTR_RULES_V.src_type%TYPE := 'API';
        l_ship_site_use_id   HZ_CUST_SITE_USES_ALL.SITE_USE_ID%TYPE := 0;
        l_bill_site_use_id   HZ_CUST_SITE_USES_ALL.SITE_USE_ID%TYPE := 0;
        sql_stmt             VARCHAR2 (2000) := NULL;
        l_disp_err_msg       VARCHAR2 (4000) := NULL;
        l_proc_name          VARCHAR2 (150) := 'GET_ATTR_VAL';
    BEGIN
        IF p_src_type = l_rel_rec                            -- RELATED_RECORD
        THEN
            l_attr_val   := NULL;

            IF (l_attr_val IS NULL AND p_src_database_object_name = 'OE_AK_SHIP_TO_ORGS_V')
            THEN
                -- Fetching Customer ship-to site use ID
                l_ship_site_use_id   := get_site_use_id ('SHIP_TO');

                IF ONT_SHIP_TO_ORG_Def_Util.Sync_SHIP_TO_ORG_Cache (
                       p_ORGANIZATION_ID => l_ship_site_use_id) =
                   1
                THEN  --Pass HZ_CUST_SITE_USES_ALL.site_use_id of the customer
                    l_attr_val   :=
                        ONT_SHIP_TO_ORG_Def_Util.Get_Attr_Val_Varchar2 (
                            p_attribute_code,
                            ONT_SHIP_TO_ORG_Def_Util.g_cached_record);
                END IF;
            END IF;

            IF (l_attr_val IS NULL AND p_src_database_object_name = 'OE_AK_INVOICE_TO_ORGS_V')
            THEN
                -- Fetching Customer Bill-to site use ID
                l_bill_site_use_id   := get_site_use_id ('BILL_TO');

                IF ONT_INV_ORG_Def_Util.Sync_INV_ORG_Cache (
                       p_ORGANIZATION_ID => l_bill_site_use_id) =
                   1
                THEN  --Pass HZ_CUST_SITE_USES_ALL.site_use_id of the customer
                    l_attr_val   :=
                        ONT_INV_ORG_Def_Util.Get_Attr_Val_Varchar2 (
                            p_attribute_code,
                            ONT_INV_ORG_Def_Util.g_cached_record);
                END IF;
            END IF;

            IF (l_attr_val IS NULL AND p_src_database_object_name = 'OE_AK_SOLD_TO_ORGS_V')
            THEN
                IF ONT_SOLD_TO_ORG_Def_Util.Sync_SOLD_TO_ORG_Cache (
                       p_ORGANIZATION_ID   => g_cust_acct_id, -- Pass cust_account_id of customer
                       p_ORG_ID            => g_org_id) =
                   1
                THEN                                            -- Pass org_id
                    l_attr_val   :=
                        ONT_SOLD_TO_ORG_Def_Util.Get_Attr_Val_Varchar2 (
                            p_attribute_code,
                            ONT_SOLD_TO_ORG_Def_Util.g_cached_record);
                END IF;
            END IF;

            IF (l_attr_val IS NULL AND p_src_database_object_name = 'OE_PRICE_LISTS_V')
            THEN
                IF ONT_PRICE_LIST_Def_Util.Sync_PRICE_LIST_Cache (
                       p_PRICE_LIST_ID => g_price_list_id) =
                   1
                THEN -- Pass price list id -- But price list id itself has to be derived/defaulted
                    l_attr_val   :=
                        ONT_PRICE_LIST_Def_Util.Get_Attr_Val_Varchar2 (
                            p_attribute_code,
                            ONT_PRICE_LIST_Def_Util.g_cached_record);
                END IF;
            END IF;
        ELSIF p_src_type = l_api                                        -- API
        THEN
            l_attr_val   := NULL;

            IF p_attribute_code = 'PRICE_LIST_ID'
            THEN
                -- Code From xxd_do_om_default_rules.ret_hpricelist
                BEGIN
                    SELECT DISTINCT qlh.list_header_id
                      INTO l_attr_val
                      FROM apps.xxd_default_pricelist_matrix xt, apps.qp_list_headers_vl qlh
                     WHERE     brand = g_brand                   -- Pass Brand
                           AND NVL (TO_DATE (g_ordered_date, 'RRRR-MM-DD'),
                                    SYSDATE) BETWEEN NVL (
                                                         xt.order_start_date,
                                                         SYSDATE)
                                                 AND NVL (xt.order_end_date,
                                                          SYSDATE)
                           AND NVL (TO_DATE (g_requested_date, 'RRRR-MM-DD'),
                                    SYSDATE) BETWEEN NVL (
                                                         xt.requested_start_date,
                                                         SYSDATE)
                                                 AND NVL (
                                                         xt.requested_end_date,
                                                         SYSDATE)
                           AND xt.OPERATING_UNIT =
                               (SELECT name
                                  FROM hr_operating_units
                                 WHERE organization_id = g_org_id) -- Pass Org_ID
                           AND xt.customer_class = g_class_code -- Pass Customer Class code
                           AND xt.PRICE_LIST_NAME = qlh.NAME;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        l_attr_val       := NULL;
                        l_disp_err_msg   :=
                               'Price_list_id does not exist for brand: '
                            || g_brand
                            || ' Ordered Date: '
                            || g_ordered_date
                            || ' Requested Date: '
                            || g_requested_date
                            || ' and class code: '
                            || g_class_code;
                        g_err_num        := g_err_num + 1;
                        log_errors_bk (g_err_num, g_pkg_name, l_proc_name,
                                       l_disp_err_msg);
                    WHEN OTHERS
                    THEN
                        DBMS_OUTPUT.put_line (
                               'Error While Fetching Price_list_id for brand: '
                            || g_brand
                            || ' Ordered Date: '
                            || g_ordered_date
                            || ' Requested Date: '
                            || g_requested_date
                            || ' and class code: '
                            || g_class_code
                            || ': '
                            || SQLERRM);
                        g_err_num   := g_err_num + 1;
                        log_errors_bk (g_err_num, g_pkg_name, l_proc_name,
                                       l_disp_err_msg);
                END;
            END IF;
        /*  IF p_attribute_code = 'SHIP_TO_ORG_ID'
          THEN
             -- Query From xxd_do_om_default_rules.ret_ship_to_loc -- same as in function get_site_use_id
             l_attr_val := get_site_use_id ('SHIP_TO');
          END IF;*/
        -- Commented by Lakshmi BTDEV Team on 17-MAR-2015
        END IF;

        p_attr_val   := l_attr_val;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_disp_err_msg   :=
                'Error in procedure get_attr_val: ' || SQLERRM;
            DBMS_OUTPUT.put_line (l_disp_err_msg);
            g_err_num   := g_err_num + 1;
            log_errors_bk (g_err_num, g_pkg_name, l_proc_name,
                           l_disp_err_msg);
    END get_attr_val;

    -- ***************************************************************************
    -- Function :  get_sales_rep_id
    -- Description: Function to derive the default salesrep from the sales rep matrix maintained in a cross reference mapping table
    -- by brand, customer and customer ship-to and product hierarchy combination
    -- ***************************************************************************
    FUNCTION get_sales_rep_id (p_inv_item_id IN NUMBER, p_org_id IN NUMBER, p_cust_acct_id IN NUMBER
                               , p_ship_to_org_id IN NUMBER)
        RETURN NUMBER
    IS
        CURSOR get_product_det_c IS
            SELECT DISTINCT brand, division, department,
                            master_class, sub_class, style_number, -- Added for CCR0005785
                            color_code                 -- Added for CCR0005785
              FROM xxd_common_items_v
             WHERE inventory_item_id = p_inv_item_id;

        lcu_product_det   get_product_det_c%ROWTYPE;
        l_salesrep_id     NUMBER := 0;
        l_disp_err_msg    VARCHAR2 (4000) := NULL;
        l_proc_name       VARCHAR2 (150) := 'GET_SALES_REP_ID';
    BEGIN
        OPEN get_product_det_c;

        FETCH get_product_det_c INTO lcu_product_det;

        CLOSE get_product_det_c;

        IF     p_org_id IS NOT NULL
           AND p_cust_acct_id IS NOT NULL
           AND lcu_product_det.brand IS NOT NULL
           AND p_ship_to_org_id IS NOT NULL
        THEN
            l_salesrep_id   :=
                XXD_OE_SALESREP_ASSN_PKG.GET_SALES_REP (
                    p_org_id,
                    p_cust_acct_id,
                    p_ship_to_org_id,
                    lcu_product_det.brand,
                    lcu_product_det.division,
                    lcu_product_det.department,
                    lcu_product_det.master_class,
                    lcu_product_det.sub_class,
                    lcu_product_det.style_number,      -- Added for CCR0005785
                    lcu_product_det.color_code         -- Added for CCR0005785
                                              );
        END IF;

        RETURN l_salesrep_id;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            l_disp_err_msg   :=
                   'Sales Rep ID Not Found For the Customer ID: '
                || p_cust_acct_id
                || 'Brand: '
                || lcu_product_det.brand
                || 'Ship-To Org ID: '
                || p_ship_to_org_id
                || ' And Org ID: '
                || p_org_id;
            DBMS_OUTPUT.put_line (l_disp_err_msg);
            g_err_num   := g_err_num + 1;
            log_errors_bk (g_err_num, g_pkg_name, l_proc_name,
                           l_disp_err_msg);
            RETURN NULL;
        WHEN OTHERS
        THEN
            l_disp_err_msg   :=
                   'Error While Fetching Sales Rep ID For the Customer ID: '
                || p_cust_acct_id
                || 'Brand: '
                || lcu_product_det.brand
                || 'Ship-To Org ID: '
                || p_ship_to_org_id
                || ' And Org ID: '
                || p_org_id
                || ': '
                || SQLERRM;
            DBMS_OUTPUT.put_line (l_disp_err_msg);
            g_err_num   := g_err_num + 1;
            log_errors_bk (g_err_num, g_pkg_name, l_proc_name,
                           l_disp_err_msg);
            RETURN NULL;
    END get_sales_rep_id;

    -- ***************************************************************************
    -- Function :  get_blanket_hdr
    -- Description: Function to return the sales agreement number to populate on the Sales Release - RL File
    -- ***************************************************************************
    FUNCTION get_blanket_hdr (p_cust_acct_id   IN NUMBER,
                              p_org_id         IN NUMBER,
                              p_cust_po_num    IN VARCHAR2)
        RETURN NUMBER
    IS
        l_bsa_hdr_num    oe_blanket_headers_all.order_number%TYPE := NULL;
        l_disp_err_msg   VARCHAR2 (4000) := NULL;
        l_proc_name      VARCHAR2 (150) := 'GET_BLANKET_HDR';
    BEGIN
        -- Deleting From The error table
        -- DELETE FROM XXDO.xxdo_rl_bsa_errors; -- DML operation is not allowed in query.
        -- COMMIT;  -- Commented, since SOA will use XA data source.

        /*  SELECT ORDER_NUMBER                                     --blanket_number
            INTO l_bsa_hdr_num
            FROM ONT.oe_blanket_headers_all
           WHERE     sold_to_org_id = p_cust_acct_id
                 AND flow_status_code = 'ACTIVE'
                 AND org_id = p_org_id; */
        -- Commented by Lakshmi BTDEV Team on 01-Jun-2015 for 1.4

        -- Added by Lakshmi BTDEV Team on 01-Jun-2015 for 1.4.
        SELECT obh.ORDER_NUMBER                               --blanket_number
          INTO l_bsa_hdr_num
          FROM oe_blanket_headers_all obh, oe_blanket_headers_ext obhe
         WHERE     obh.order_number = obhe.order_number
               AND sold_to_org_id = p_cust_acct_id
               AND flow_status_code = 'ACTIVE'
               AND org_id = p_org_id
               AND cust_po_number = p_cust_po_num
               AND SYSDATE BETWEEN NVL (obhe.start_date_active, SYSDATE)
                               AND NVL (obhe.end_date_active, SYSDATE);

        RETURN l_bsa_hdr_num;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    -- ***************************************************************************
    -- Function :  get_blanket_line
    -- Description: Function to return the sales agreement line number to populate on the Sales Release RL File
    -- ***************************************************************************
    FUNCTION get_blanket_line (p_cust_acct_id IN NUMBER, p_org_id IN NUMBER, p_inv_item_id IN NUMBER
                               , p_cust_po_num IN VARCHAR2)
        RETURN NUMBER
    IS
        l_bsa_line_num   oe_blanket_lines_all.line_number%TYPE := NULL;
        l_disp_err_msg   VARCHAR2 (4000) := NULL;
        l_proc_name      VARCHAR2 (150) := 'GET_BLANKET_LINE';
    BEGIN
        /*  SELECT LINE_NUMBER                                 --blanket_line_number
            INTO l_bsa_line_num
            FROM oe_blanket_lines_all obla, oe_blanket_headers_all obha
           WHERE     obla.header_id = obha.header_id
                 AND obla.sold_to_org_id = p_cust_acct_id
                 AND obla.inventory_item_id = p_inv_item_id
                 AND obla.org_id = p_org_id
                 AND obha.flow_status_code = 'ACTIVE'; */
        -- Commented by Lakshmi BTDEV Team on 01-Jun-2015 for 1.4

        -- Added by Lakshmi BTDEV Team on 01-Jun-2015 for 1.4.
        SELECT LINE_NUMBER                               --blanket_line_number
          INTO l_bsa_line_num
          FROM oe_blanket_lines_all obla, oe_blanket_headers_all obh, oe_blanket_headers_ext obhe
         WHERE     obla.header_id = obh.header_id
               AND obh.order_number = obhe.order_number
               AND obh.sold_to_org_id = p_cust_acct_id
               AND obh.flow_status_code = 'ACTIVE'
               AND obh.org_id = p_org_id
               AND obh.cust_po_number = p_cust_po_num
               AND SYSDATE BETWEEN NVL (obhe.start_date_active, SYSDATE)
                               AND NVL (obhe.end_date_active, SYSDATE)
               AND inventory_item_id = p_inv_item_id;

        RETURN l_bsa_line_num;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    PROCEDURE log_errors_bk (p_err_num IN NUMBER, p_pkg_name IN VARCHAR2, p_proc_name IN VARCHAR2
                             , p_err_msg IN VARCHAR2)
    IS
    BEGIN
        INSERT INTO XXDO.xxdo_bk_bsa_errors (Error_Num, package_name, procedure_name
                                             , creation_date, error_message)
             VALUES (p_err_num, p_pkg_name, p_proc_name,
                     SYSDATE, p_err_msg);
    -- COMMIT; -- Commented, since SOA will use XA data source.

    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line (
                'Error in procedure log_errors_bk: ' || SQLERRM);
    END log_errors_bk;
/* -- Commented since not being used.
PROCEDURE log_errors_rl (p_err_num     IN NUMBER,
                         p_pkg_name    IN VARCHAR2,
                         p_proc_name   IN VARCHAR2,
                         p_err_msg     IN VARCHAR2)
IS
BEGIN
   INSERT INTO XXDO.xxdo_rl_bsa_errors (Error_Num,
                                        package_name,
                                        procedure_name,
                                        creation_date,
                                        error_message)
        VALUES (p_err_num,
                p_pkg_name,
                p_proc_name,
                SYSDATE,
                p_err_msg);

   -- COMMIT; -- Commented, since SOA will use XA data source.
EXCEPTION
   WHEN OTHERS
   THEN
      DBMS_OUTPUT.put_line (
         'Error in procedure log_errors_rl: ' || SQLERRM);
END log_errors_rl;
*/
END XXDO_BK_BSA_CREATE;
/


--
-- XXDO_BK_BSA_CREATE  (Synonym) 
--
CREATE OR REPLACE SYNONYM SOA_INT.XXDO_BK_BSA_CREATE FOR APPS.XXDO_BK_BSA_CREATE
/


GRANT EXECUTE ON APPS.XXDO_BK_BSA_CREATE TO SOA_INT
/
