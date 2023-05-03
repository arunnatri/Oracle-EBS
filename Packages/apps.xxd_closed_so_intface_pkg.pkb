--
-- XXD_CLOSED_SO_INTFACE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:03 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_CLOSED_SO_INTFACE_PKG"
AS
    /****************************************************************************************/
    /* PACKAGE NAME:  XXD_CLOSED_SO_INTFACE_PKG                                             */
    /*                                                                                      */
    /* PROGRAM NAME:  Extract_Records_Proc - Extraction Program                             */
    /*                                                                                      */
    /*                                                                                      */
    /*                                                                                      */
    /*                                                                                      */
    /* DEPENDENCIES:  XXD_common_utils                                                      */
    /*                                                                                      */
    /* REFERENCED BY: N/A                                                                   */
    /*                                                                                      */
    /* DESCRIPTION:   Sales Order Conversion For Demantra                                   */
    /*                                                                                      */
    /* HISTORY:                                                                             */
    /*--------------------------------------------------------------------------------------*/
    /* No     Developer       Date      Description                                         */
    /*                                                                                      */
    /*--------------------------------------------------------------------------------------*/
    /* 1.00     XXX      04-SEP-2014  Package Body script for  Sales Order Conversion.      */
    /*                                                                                      */
    /****************************************************************************************/
    -- Global Variable Declaration
    g_org_id                      NUMBER;
    g_login_id                    NUMBER := FND_GLOBAL.LOGIN_ID;
    g_user_id                     NUMBER := fnd_profile.VALUE ('USER_ID');
    g_date                        DATE := SYSDATE;
    g_conc_request_id             NUMBER := fnd_global.conc_request_id;
    g_progress                    VARCHAR2 (5000);
    gc_custom_appl_name           fnd_application.application_short_name%TYPE
                                      := 'XXD';
    g_success                     VARCHAR2 (1) := 0;
    g_warning                     VARCHAR2 (1) := 1;
    g_failed                      VARCHAR2 (1) := 2;
    g_limit                       NUMBER := 1000;
    g_debug                       VARCHAR2 (1) := 'N';            --Latest #BT
    gc_validate_status   CONSTANT VARCHAR2 (20) := 'VALIDATED';
    gc_error_status      CONSTANT VARCHAR2 (20) := 'ERROR';
    gc_new_status        CONSTANT VARCHAR2 (20) := 'NEW';
    gc_process_status    CONSTANT VARCHAR2 (20) := 'PROCESSED';
    gc_interfaced        CONSTANT VARCHAR2 (20) := 'INTERFACED';


    /*============================================================================================+
    |  PROCEDURE NAME :  Extract_Records_Proc                                                     |
    |  DESCRIPTION:      Procedure to Extract Sales Order in the staging tables.                  |
    |  Parameters    :                                                                            |
    |                    p_Return_Mesg    OUT  Error message                                      |
    |                    p_Return_Code    OUT  Error code                                         |
    |                    p_from_date      IN   From date to extract the Sales Order Data          |
    |                    p_to_date        IN   Till date to which extract the Sales Order Data    |
    |                    p_data           IN   Used to identify how the output should be Grouped. |
    |                    p_debug          IN   Used to switch On/Off the Debug mode                 |            --Latest #BT
    +=============================================================================================*/
    PROCEDURE extract_records_proc (p_return_mesg OUT VARCHAR2, p_return_code OUT VARCHAR2, p_from_date IN VARCHAR2
                                    , p_to_date IN VARCHAR2, p_data IN VARCHAR2, p_debug IN VARCHAR2 --Latest #BT
                                                                                                    )
    IS
        -- Local Variable Declaration
        lv_error_msg           VARCHAR2 (4000);
        ln_error_count         NUMBER;
        lv_msg                 VARCHAR2 (4000);
        ln_idx                 NUMBER;
        ld_from_date           DATE := FND_DATE.CANONICAL_TO_DATE (p_from_date);
        ld_to_date             DATE := FND_DATE.CANONICAL_TO_DATE (p_to_date);
        e_header_bulk_errors   EXCEPTION;
        PRAGMA EXCEPTION_INIT (E_HEADER_BULK_ERRORS, -24381);

        -- Cursor to fetch the data from interface view
        CURSOR get_so_rec_c IS
            SELECT xdiv.*
              FROM xxd_demantra_iface_v xdiv
             WHERE TRUNC (xdiv.sales_date) BETWEEN ld_from_date
                                               AND ld_to_date;

        TYPE so_table_type IS TABLE OF get_so_rec_c%ROWTYPE
            INDEX BY BINARY_INTEGER;

        so_table_tbl           so_table_type;
    BEGIN
        -- Writing the selected parameters to the log file
        fnd_file.put_line (fnd_file.LOG,
                           RPAD (('p_data  '), 15, ' ') || ' : ' || p_data);
        fnd_file.put_line (
            fnd_file.LOG,
            RPAD (('ld_from_date  '), 15, ' ') || ' : ' || ld_from_date);
        fnd_file.put_line (
            fnd_file.LOG,
            RPAD (('ld_to_date  '), 15, ' ') || ' : ' || ld_to_date);
        fnd_file.put_line (fnd_file.LOG,
                           RPAD (('p_debug '), 15, ' ') || ' : ' || p_debug);
        fnd_file.put_line (fnd_file.LOG, RPAD ((' '), 40, '-'));

        fnd_file.put_line (fnd_file.LOG, 'Begining of the Conversion ...');

        g_debug         := p_debug;

        p_return_code   := g_success;

        IF (p_data = 'QUANTITY')
        THEN
            g_progress   :=
                'Truncating the staging table XXD_DEMANTRA_STG_IFACE_T';

            fnd_file.put_line (fnd_file.LOG, g_progress);

            EXECUTE IMMEDIATE 'TRUNCATE TABLE XXD_CONV.XXD_DEMANTRA_STG_IFACE_T '; -- Truncate the staging table

            g_progress   := 'Extracting data into staging table';

            fnd_file.put_line (fnd_file.LOG, g_progress);

            OPEN get_so_rec_c;

            so_table_tbl.DELETE;

            LOOP
                -- Fetching the data from the view to Insert into Staging Table
                FETCH get_so_rec_c
                    BULK COLLECT INTO so_table_tbl
                    LIMIT g_limit;

                IF g_debug = 'Y'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        ' so_table_tbl.COUNT : ' || so_table_tbl.COUNT);
                END IF;

                EXIT WHEN so_table_tbl.COUNT = 0;

                BEGIN
                    FORALL ln_indx IN 1 .. so_table_tbl.COUNT SAVE EXCEPTIONS
                        -- Inserting the data into Staging table
                        INSERT INTO XXD_DEMANTRA_STG_IFACE_T (
                                        RECORD_ID,
                                        RECORD_STATUS,
                                        ACTUAL_QTY,
                                        SALES_DATE,
                                        DM_ITEM_CODE,
                                        DM_ORG_CODE,
                                        INV_ORG_ID,
                                        ORG_ID,
                                        ACCOUNT_NUMBER,
                                        PARTY_NAME,                    --#BT 1
                                        SHIP_TO_ORG_ID,                --#BT 1
                                        --PARTY_INFO,            --#BT 1
                                        INVENTORY_ITEM_ID,
                                        BOOKED_DATE,
                                        REQUEST_DATE,
                                        ORDERED_QUANTITY,
                                        PRICE,
                                        ORDER_TYPE_ID,
                                        EBS_SALES_CHANNEL_CODE,
                                        EBS_DEMAND_CLASS_CODE,
                                        EBS_BOOK_HISTBOOK_QTY_BD,
                                        EBS_BOOK_HIST_REQ_QTY_BD,
                                        EBS_BOOK_HIST_BOOK_QTY_RD,
                                        EBS_BOOK_HIST_REQ_QTY_RD,
                                        EBS_SHIP_HIST_SHIP_QTY_SD,
                                        EBS_SHIP_HIST_SHIP_QTY_RD,
                                        EBS_SHIP_HIST_REQ_QTY_RD,
                                        EBS_PARENT_ITEM_CODE,
                                        EBS_BASE_MODEL_CODE,
                                        status_flag,
                                        ERROR_MESSAGE,
                                        REQUEST_ID,
                                        PARENT_REQUEST_ID,
                                        DATA_FILE_NAME,
                                        CREATED_BY,
                                        CREATION_DATE,
                                        LAST_UPDATED_BY,
                                        LAST_UPDATE_DATE,
                                        LAST_UPDATE_LOGIN,
                                        GROUP_SALES_DATE,
                                        location,
                                        brand)
                                 VALUES (
                                            xxd_so_header_intface_stg_s.NEXTVAL,
                                            'N',
                                            so_table_tbl (ln_indx).ACTUAL_QTY,
                                            so_table_tbl (ln_indx).SALES_DATE,
                                            so_table_tbl (ln_indx).DM_ITEM_CODE,
                                            so_table_tbl (ln_indx).DM_ORG_CODE,
                                            so_table_tbl (ln_indx).INV_ORG_ID,
                                            so_table_tbl (ln_indx).ORG_ID,
                                            so_table_tbl (ln_indx).ACCOUNT_NUMBER,
                                            so_table_tbl (ln_indx).PARTY_NAME, --#BT 1
                                            so_table_tbl (ln_indx).SHIP_TO_ORG_ID, --#BT 1
                                            --so_table_tbl(ln_indx). PARTY_INFO,            --#BT 1
                                            so_table_tbl (ln_indx).INVENTORY_ITEM_ID,
                                            so_table_tbl (ln_indx).BOOKED_DATE,
                                            so_table_tbl (ln_indx).REQUEST_DATE,
                                            so_table_tbl (ln_indx).ORDERED_QUANTITY,
                                            so_table_tbl (ln_indx).PRICE,
                                            so_table_tbl (ln_indx).ORDER_TYPE_ID,
                                            NULL,
                                            so_table_tbl (ln_indx).EBS_DEMAND_CLASS_CODE,
                                               so_table_tbl (ln_indx).INVENTORY_ITEM_ID
                                            || '-'
                                            || so_table_tbl (ln_indx).BOOKED_DATE
                                            || '-'
                                            || so_table_tbl (ln_indx).ORDERED_QUANTITY,
                                            NULL,
                                            NULL,
                                               so_table_tbl (ln_indx).INVENTORY_ITEM_ID
                                            || '-'
                                            || so_table_tbl (ln_indx).REQUEST_DATE
                                            || '-'
                                            || so_table_tbl (ln_indx).ORDERED_QUANTITY,
                                               so_table_tbl (ln_indx).INVENTORY_ITEM_ID
                                            || '-'
                                            || so_table_tbl (ln_indx).SALES_DATE
                                            || '-'
                                            || so_table_tbl (ln_indx).ACTUAL_QTY,
                                            NULL,
                                            NULL,
                                            so_table_tbl (ln_indx).EBS_PARENT_ITEM_CODE,
                                            so_table_tbl (ln_indx).EBS_BASE_MODEL_CODE,
                                            gc_new_status,
                                            lv_error_msg,
                                            g_conc_request_id,
                                            NULL,
                                            'DEMANTRA SALES ORDER CONV',
                                            g_user_id,
                                            g_date,
                                            g_user_id,
                                            g_date,
                                            g_login_id,
                                            NULL,
                                            so_table_tbl (ln_indx).location,
                                            so_table_tbl (ln_indx).brand);
                EXCEPTION      -- Exception Handling for the Inner Begin/Block
                    WHEN E_HEADER_BULK_ERRORS
                    THEN
                        IF (get_so_rec_c%ISOPEN)
                        THEN
                            CLOSE get_so_rec_c;
                        END IF;

                        ln_error_count   := SQL%BULK_EXCEPTIONS.COUNT;

                        FOR i IN 1 .. ln_error_count
                        LOOP
                            lv_msg   :=
                                SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE);
                            ln_idx   := SQL%BULK_EXCEPTIONS (i).ERROR_INDEX;
                            g_progress   :=
                                'CaughtException while extraction of data';
                            fnd_file.put_line (fnd_file.LOG,
                                               g_progress || SQLERRM);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error Code : '
                                || lv_msg
                                || ' Errorindex : '
                                || ln_idx);
                        END LOOP;
                    WHEN OTHERS
                    THEN
                        IF (get_so_rec_c%ISOPEN)
                        THEN
                            CLOSE get_so_rec_c;
                        END IF;

                        /*
                                          xxd_common_utils.record_error (
                                             p_module       => 'SO',
                                             p_org_id       => g_org_id,
                                             p_program      => 'Extract_Records_Proc',
                                             p_error_line   => SQLCODE,
                                             p_error_msg    =>    'Error while extracting the data '
                                                               || SUBSTR ('Error:-' || SQLERRM,
                                                                          1,
                                                                          499),
                                             p_created_by   => g_user_id,
                                             p_request_id   => g_conc_request_id);
                        */
                        p_return_code   := g_failed;
                        p_return_mesg   := SQLCODE || ' ~ ' || SQLERRM;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error Occured in the Inner block while Extracting the data : '
                            || p_return_mesg);
                END;                               -- End of Inner Begin/Block
            END LOOP;

            g_progress   := 'Extracting the data to Staging table Completed';

            fnd_file.put_line (fnd_file.LOG, g_progress);

            IF (get_so_rec_c%ISOPEN)
            THEN
                CLOSE get_so_rec_c;
            END IF;

            --       CLOSE get_so_rec_c;                             -- Closing the Cursor

            COMMIT;              -- To Commit the records to the Staging Table

            g_progress   := 'Calling to Perform the required deriviations...';

            fnd_file.put_line (fnd_file.LOG, g_progress);

            derive_update_proc;           -- Call to perform the deriviations.

            g_progress   :=
                'Call to Display the output grouped by Sum of Quantity...';

            fnd_file.put_line (fnd_file.LOG, g_progress);

            display_quantity_proc; -- Calling to Display the output grouped by Sum of Quantity.
        ELSE
            -- Before user opting to get the ouptut grouped by Average Price(p_data = PRICE)
            -- It is expected that he/she should have run the program for(p_data = QUANTITY)
            -- As we are using the same extracted and derived data for printing the output based on Average Price.

            g_progress   :=
                'Call to Display the output grouped by Average Price ...';

            fnd_file.put_line (fnd_file.LOG, g_progress);

            display_price_proc; -- Calling to Display the output grouped by Average Price.
        END IF;
    EXCEPTION               -- Exception Handling for the Main Block/Procedure
        WHEN OTHERS
        THEN
            /*
                     xxd_common_utils.record_error (
                        p_module       => 'SO',
                        p_org_id       => g_org_id,
                        p_program      => 'Extract_Records_Proc',
                        p_error_line   => SQLCODE,
                        p_error_msg    =>    'Error while extracting the data '
                                          || SUBSTR ('Error:-' || SQLERRM, 1, 499),
                        p_created_by   => g_user_id,
                        p_request_id   => g_conc_request_id);
            */
            p_return_code   := g_failed;
            p_return_mesg   := SQLCODE || ' ~ ' || SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Occured while in Extract_Records_Proc  : '
                || p_return_mesg);
    END Extract_Records_Proc;     -- End of the Procedure Extract_Records_Proc


    /*--==============================================================================+
    |--  PROCEDURE NAME :  derive_update_proc                                         |
    |--  DESCRIPTION    :  Procedure to perform the required derivations and          |
    |--                    Updating the Staging table accordingly.                    |
    |--  Parameters     :  No Parameters                                              |
    +--===============================================================================*/

    PROCEDURE derive_update_proc
    AS
        -- Local Variable Declaration

        lv_new_org_code       VARCHAR2 (200) := NULL;

        ld_group_sales_date   DATE; -- Variable created to extract the the group Sales Date for the coming Monday

        lv_operating_unit     VARCHAR2 (400); -- Variable to extract the value of Operating unit

        lv_final_site_code    VARCHAR2 (1200); -- Variable to hold the final site code value

        lv_customer_name      VARCHAR2 (1200) := NULL;           -- Latest #BT

        lv_brand              VARCHAR2 (200) := NULL;            -- Latest #BT

        lv_demand_class       VARCHAR2 (200) := NULL;            -- Latest #BT

        lv_sales_channel      VARCHAR2 (200) := NULL;            -- Latest #BT

        lv_party_info         VARCHAR2 (1200) := NULL;                 -- #BT1

        lv_acct_num           VARCHAR2 (200) := NULL;                   --#BT1

        lv_party_site_num     VARCHAR2 (100) := NULL;                   --#BT1

        lc_instance_code      VARCHAR2 (100) := NULL;

        lc_error_flag         VARCHAR2 (20) := NULL;
        lc_error_message      VARCHAR2 (2000) := NULL;
        lc_ecomm_customer     VARCHAR2 (2000) := NULL;
        lc_cust_country       HZ_LOCATIONS.country%TYPE;

        CURSOR get_org_disp_c IS
            SELECT xdsi.*
              FROM xxd_demantra_stg_iface_t xdsi
             WHERE status_flag <> gc_process_status;

        TYPE org_table_type IS TABLE OF get_org_disp_c%ROWTYPE
            INDEX BY BINARY_INTEGER;

        org_table_tbl         org_table_type;
    BEGIN
        g_progress   :=
            'Called derive_update_proc and Fetching the data from Staging table ..  ';

        fnd_file.put_line (fnd_file.LOG, g_progress);


        BEGIN
            SELECT instance_code
              INTO lc_instance_code
              FROM msc.MSC_APPS_INSTANCES@BT_EBS_TO_ASCP;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (fnd_file.LOG, 'Unable to derive Instance');
        END;

        fnd_file.put_line (fnd_file.LOG,
                           'Instance code - ' || lc_instance_code);

        OPEN get_org_disp_c;

        LOOP
            FETCH get_org_disp_c   -- Fetching the data from the Staging table
                BULK COLLECT INTO org_table_tbl
                LIMIT g_limit;

            fnd_file.put_line (
                fnd_file.LOG,
                'No.of records fetched : ' || org_table_tbl.COUNT); -- Displays the no.of records fetched in each turn

            EXIT WHEN org_table_tbl.COUNT = 0;

            BEGIN
                FOR ln_indx IN 1 .. org_table_tbl.COUNT
                LOOP
                    ld_group_sales_date   := NULL;
                    lv_operating_unit     := NULL;

                    lv_final_site_code    := NULL;

                    lv_customer_name      := NULL;

                    lv_brand              := NULL;

                    lv_demand_class       := NULL;

                    lv_sales_channel      := NULL;

                    lv_party_info         := NULL;

                    lv_acct_num           := NULL;

                    lv_party_site_num     := NULL;
                    lc_error_flag         := gc_validate_status;
                    lc_error_message      := NULL;
                    lc_ecomm_customer     := NULL;
                    lc_cust_country       := NULL;
                    lv_new_org_code       := NULL;


                    -- 1.Get the Coming Monday of Sales Date.
                    SELECT NEXT_DAY (org_table_tbl (ln_indx).sales_date - 7, 'MONDAY')
                      INTO ld_group_sales_date
                      FROM DUAL;

                    IF g_debug = 'Y'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               ' Group sales date : '
                            || ld_group_sales_date
                            || ' for sales date - '
                            || org_table_tbl (ln_indx).sales_date);
                    END IF;

                    -- 2.Get the Brand from Item Categories
                    --               SELECT mcb.segment1 Brand
                    --                 INTO lv_brand
                    --                 FROM mtl_item_categories@bt_read_1206 mic,
                    --                      mtl_categories_b@bt_read_1206 mcb
                    --                WHERE     mic.category_id = mcb.category_id
                    --                      AND mic.Category_set_id = 1 --(category_set_name='Inventory');
                    --                      AND mic.organization_id =
                    --                             org_table_tbl (ln_indx).INV_ORG_ID
                    --                      AND mic.inventory_item_id =
                    --                             org_table_tbl (ln_indx).inventory_item_id;

                    --  3.Block to Derive the new Inventory Org Code.
                    BEGIN
                        SELECT flv.attribute1
                          INTO lv_new_org_code
                          FROM fnd_lookup_values flv
                         WHERE     lookup_type = 'XXD_1206_INV_ORG_MAPPING'
                               AND flv.language = 'US'
                               AND flv.lookup_code =
                                   org_table_tbl (ln_indx).INV_ORG_ID;
                    EXCEPTION
                        -- To Handle the Exceptions while deriving Inventory Org.

                        WHEN NO_DATA_FOUND
                        THEN
                            lc_error_flag   := gc_error_status;
                            lc_error_message   :=
                                   'Failed to fetch the new Inv Organization for the old_inv_org_id : '
                                || org_table_tbl (ln_indx).INV_ORG_ID;

                            -- lv_new_org_code := 'US1';            -- Latest Change #BT

                            IF g_debug = 'Y'
                            THEN                          -- Latest Change #BT
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Failed to fetch the new Inv Organization for the old_inv_org_id : '
                                    || org_table_tbl (ln_indx).INV_ORG_ID);
                            END IF;                       -- Latest Change #BT
                    END;

                    --  4.Block to Derive the Operating Unit
                    BEGIN
                        SELECT flv.attribute1
                          INTO lv_operating_unit
                          FROM fnd_lookup_values flv
                         WHERE     flv.lookup_type = 'XXD_1206_OU_MAPPING'
                               AND flv.language = 'US'
                               AND flv.lookup_code =
                                   org_table_tbl (ln_indx).ORG_ID;
                    --lv_final_site_code := org_table_tbl(ln_indx).PARTY_INFO ||':'||lv_operating_unit ;   --#BT1

                    EXCEPTION
                        -- To Handle the Exceptions while deriving Inventory Org.

                        WHEN NO_DATA_FOUND
                        THEN
                            lc_error_flag       := gc_error_status;
                            lc_error_message    :=
                                   'Failed to fetch the new Operating Unit for the old_org_id : '
                                || org_table_tbl (ln_indx).ORG_ID;


                            IF g_debug = 'Y'
                            THEN                          -- Latest Change #BT
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Failed to fetch the new Operating Unit for the old_org_id : '
                                    || org_table_tbl (ln_indx).ORG_ID);
                            END IF;                       -- Latest Change #BT

                            lv_operating_unit   := NULL;
                    END;

                    --               --Latest #BT Start
                    --               -- 5.Block for deriving the Demand Class and Sales Channel Code
                    --               BEGIN
                    --                  -- Get the Party Name
                    --                  --lv_customer_name :=  SUBSTR(org_table_tbl(ln_indx).PARTY_INFO,1,INSTR(org_table_tbl(ln_indx).PARTY_INFO,':')-1)    ;    --Latest #BT    ( -- Extracting the Customer Name)  --#BT1 COMMENTED
                    --
                    --                  SELECT xca.demand_class, xca.sales_channel
                    --                    INTO lv_demand_class, lv_sales_channel
                    --                    FROM xxd_conv.xxd_cust_account_mapping_t xca
                    --                   WHERE     xca.customer_name =
                    --                                org_table_tbl (ln_indx).PARTY_NAME -- lv_customer_name --lc_customer_name  --#BT1
                    --                         AND xca.operating_unit = lv_operating_unit
                    --                         AND xca.brand = NVL (lv_brand, 'ALL BRAND');
                    --               EXCEPTION
                    --                  WHEN NO_DATA_FOUND
                    --                  THEN
                    --                     IF g_debug = 'Y'
                    --                     THEN
                    --                        fnd_file.put_line (
                    --                           fnd_file.LOG,
                    --                              'Failed to fetch the Demand Class/Sales_Channel : '
                    --                           || org_table_tbl (ln_indx).ORG_ID);
                    --                     END IF;
                    --               END;

                    --Latest #BT END

                    --#BT1 Start
                    BEGIN
                        SELECT hca.attribute13, so.meaning, hca.attribute18
                          INTO lv_demand_class, lv_sales_channel, lc_ecomm_customer
                          FROM hz_cust_accounts hca, so_lookups so
                         WHERE     hca.account_number =
                                   org_table_tbl (ln_indx).account_number
                               AND hca.sales_channel_code = so.lookup_code
                               AND LOOKUP_TYPE = 'SALES_CHANNEL';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lc_error_flag   := gc_error_status;
                            lc_error_message   :=
                                   ' Unable to derive customer account and hence demand class and sales channel for '
                                || org_table_tbl (ln_indx).account_number;

                            IF g_debug = 'Y'
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       ' Unable to derive customer account and hence demand class and sales channel for '
                                    || org_table_tbl (ln_indx).account_number);
                            END IF;
                    END;

                    --               IF lv_demand_class IS NULL
                    --         IF lv_demand_class <> 'NON-BRAND'
                    --               THEN
                    BEGIN
                        SELECT UPPER (demandcclass)
                          INTO lv_demand_class
                          FROM xxdo.XXDO_DEMAND_CLASS_MAPPING
                         WHERE     CUSTOMER_ACCOUNT =
                                   org_table_tbl (ln_indx).ACCOUNT_NUMBER
                               AND brand = org_table_tbl (ln_indx).brand
                               AND ROWNUM = 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            --                        lc_error_flag := gc_error_status;
                            lc_error_message   :=
                                   ' Unable to derive customer account in XXDO.XXDO_DEMAND_CLASS_MAPPING '
                                || org_table_tbl (ln_indx).account_number
                                || '-'
                                || 'Brand - '
                                || org_table_tbl (ln_indx).brand;

                            IF g_debug = 'Y'
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       ' Unable to derive customer account in XXDO.XXDO_DEMAND_CLASS_MAPPING '
                                    || org_table_tbl (ln_indx).account_number
                                    || '-'
                                    || 'Brand - '
                                    || org_table_tbl (ln_indx).brand);
                            END IF;
                    END;

                    --               END IF;


                    IF lv_demand_class IS NULL OR lv_sales_channel IS NULL
                    THEN
                        lc_error_flag   := gc_error_status;
                        lc_error_message   :=
                               ' Demand class or Sales Channel NULL for customer account '
                            || org_table_tbl (ln_indx).account_number
                            || 'Demand class - '
                            || lv_demand_class
                            || 'Sales Channel - '
                            || lv_sales_channel;
                    END IF;

                    IF lc_ecomm_customer IS NOT NULL
                    THEN
                        BEGIN
                            SELECT hl.country
                              INTO lc_cust_country
                              FROM hz_cust_accounts hca, hz_party_sites hps, hz_parties hp,
                                   Hz_locations hl
                             WHERE     hca.account_number =
                                       org_table_tbl (ln_indx).account_number
                                   AND hp.party_id = hca.party_id
                                   AND hps.party_id = hp.party_id
                                   AND hl.location_id = hps.location_id
                                   AND hp.status = 'A'
                                   AND hca.status = 'A'
                                   AND hps.status = 'A'
                                   AND ROWNUM = 1;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lc_error_flag   := gc_error_status;
                                lc_error_message   :=
                                       ' Unable to derive customer country for account '
                                    || org_table_tbl (ln_indx).account_number;
                        END;

                        lv_party_site_num   := 'X';

                        lv_final_site_code   :=
                            'ECOMMERCE' || '+' || lc_cust_country;
                    ELSE
                        BEGIN
                            SELECT mps.location       -- hps.party_site_number
                              INTO lv_party_site_num
                              FROM msc_trading_partner_sites@BT_EBS_TO_ASCP mps, msc_trading_partners@BT_EBS_TO_ASCP mp
                             WHERE     mp.partner_number =
                                       org_table_tbl (ln_indx).account_number
                                   AND mps.location =
                                       org_table_tbl (ln_indx).location
                                   AND mps.partner_id = mp.partner_id
                                   AND mps.tp_site_code = 'SHIP_TO'
                                   AND ROWNUM = 1;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                IF g_debug = 'Y'
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Could not derive the same location as in VCP : '
                                        || org_table_tbl (ln_indx).account_number
                                        || org_table_tbl (ln_indx).location);

                                    BEGIN
                                        SELECT mps.location -- hps.party_site_number
                                          INTO lv_party_site_num
                                          FROM msc_trading_partner_sites@BT_EBS_TO_ASCP mps, msc_trading_partners@BT_EBS_TO_ASCP mp
                                         WHERE     mp.partner_number =
                                                   org_table_tbl (ln_indx).account_number
                                               AND mps.partner_id =
                                                   mp.partner_id
                                               AND mps.tp_site_code =
                                                   'SHIP_TO'
                                               AND ROWNUM = 1;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            lc_error_flag   :=
                                                gc_error_status;
                                            lc_error_message   :=
                                                   'Could not derive the ANY location as in VCP : '
                                                || org_table_tbl (ln_indx).account_number
                                                || org_table_tbl (ln_indx).location;

                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                   'Could not derive the ANY location as in VCP : '
                                                || org_table_tbl (ln_indx).account_number
                                                || org_table_tbl (ln_indx).location);
                                    END;
                                END IF;
                        END;

                        lv_final_site_code   :=
                               org_table_tbl (ln_indx).PARTY_NAME
                            || ':'
                            || org_table_tbl (ln_indx).account_number
                            || ':'
                            || lv_party_site_num
                            || ':'
                            || lv_operating_unit;
                    END IF;

                    -- #BT1 End of Changes

                    /*
                                   lv_party_info :=
                                         org_table_tbl (ln_indx).PARTY_NAME
                                      || ':'
                                      || lv_acct_num
                                      || ':'
                                      || lv_party_site_num;
                    */

                    IF lv_party_site_num IS NULL
                    THEN
                        lc_error_flag   := gc_error_status;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               ' Unable to derive location/site information for  '
                            || org_table_tbl (ln_indx).account_number
                            || org_table_tbl (ln_indx).location);
                    END IF;



                    --               IF lc_error_flag = gc_error_status
                    --               THEN
                    --                  fnd_file.put_line (fnd_file.LOG, ' ' || );
                    --               END IF;

                    -- Updating the table using the values derived above.
                    UPDATE xxd_demantra_stg_iface_t
                       SET dm_site_code = lv_final_site_code, dm_org_code = lc_instance_code || ':' || lv_new_org_code, group_sales_date = ld_group_sales_date,
                           ebs_demand_class_code = lv_demand_class --Latest #BT
                                                                  , ebs_sales_channel_code = lv_sales_channel, --Latest #BT
                                                                                                               status_flag = lc_error_flag,
                           error_message = lc_error_message
                     WHERE record_id = org_table_tbl (ln_indx).record_id;
                END LOOP;
            EXCEPTION          -- Exception Handling for the Inner Begin/Block
                WHEN OTHERS
                THEN
                    IF (get_org_disp_c%ISOPEN)
                    THEN
                        CLOSE get_org_disp_c;
                    END IF;

                    /*
                                   xxd_common_utils.record_error (
                                      p_module       => 'SO',
                                      p_org_id       => g_org_id,
                                      p_program      => 'Extract_Records_Proc',
                                      p_error_line   => SQLCODE,
                                      p_error_msg    =>    'Error while extract data '
                                                        || SUBSTR ('Error:-' || SQLERRM, 1, 499),
                                      p_created_by   => g_user_id,
                                      p_request_id   => g_conc_request_id);
                    */

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error Occured while executing the derive_update_proc :  '
                        || SQLERRM);
            END;                                   -- End of Inner Begin/Block
        END LOOP;

        IF (get_org_disp_c%ISOPEN)
        THEN
            CLOSE get_org_disp_c;
        END IF;

        COMMIT;
    EXCEPTION               -- Exception Handling for the Main Block/Procedure
        WHEN OTHERS
        THEN
            /*
                     xxd_common_utils.record_error (
                        p_module       => 'SO',
                        p_org_id       => g_org_id,
                        p_program      => 'Extract_Records_Proc',
                        p_error_line   => SQLCODE,
                        p_error_msg    =>    'Error while extract data '
                                          || SUBSTR ('Error:-' || SQLERRM, 1, 499),
                        p_created_by   => g_user_id,
                        p_request_id   => g_conc_request_id);
            */
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Occured while executing the derive_update_proc  '
                || 'SQLCODE - '
                || SQLCODE
                || 'Errormsg'
                || SQLERRM);
    END derive_update_proc;


    /*--==============================================================================+
    | --  PROCEDURE NAME :  display_quantity_proc                                     |
    | --  DESCRIPTION    :  Procedure to display the output Aggregated by Price.      |
    | --  Parameters     :  No Parameters                                             |
    + --=============================================================================*/
    PROCEDURE display_quantity_proc
    AS
        CURSOR get_stg_disp_c IS
              SELECT TRUNC (group_sales_date) GROUP_SALES_DATE, SUM (actual_qty) sum_qty, dm_item_code,
                     dm_org_code, dm_site_code, ebs_sales_channel_code,
                     ebs_demand_class_code
                FROM xxd_demantra_stg_iface_t
               WHERE status_flag <> gc_error_status
            GROUP BY TRUNC (group_sales_date), dm_item_code, dm_org_code,
                     dm_site_code, ebs_sales_channel_code, ebs_demand_class_code;

        TYPE stg_table_type IS TABLE OF get_stg_disp_c%ROWTYPE
            INDEX BY BINARY_INTEGER;

        stg_table_tbl   stg_table_type;
    BEGIN
        g_progress   := 'Display  data from the staging table';

        fnd_file.put_line (fnd_file.LOG, g_progress);

        OPEN get_stg_disp_c;

        LOOP
            FETCH get_stg_disp_c
                BULK COLLECT INTO stg_table_tbl
                LIMIT g_limit;

            EXIT WHEN stg_table_tbl.COUNT = 0;

            BEGIN
                IF g_debug = 'Y'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Total no of records fetched :' || stg_table_tbl.COUNT);
                END IF;

                FOR ln_indx IN 1 .. stg_table_tbl.COUNT
                LOOP
                    fnd_file.put_line (
                        fnd_file.output,
                           stg_table_tbl (ln_indx).SUM_QTY
                        || '~'
                        || stg_table_tbl (ln_indx).GROUP_SALES_DATE
                        || '~'
                        || stg_table_tbl (ln_indx).DM_ITEM_CODE
                        || '~'
                        || stg_table_tbl (ln_indx).DM_ORG_CODE
                        || '~'
                        || stg_table_tbl (ln_indx).DM_SITE_CODE
                        --||'~'|| NULL                                                    -- Latest #BT
                        --||'~'|| NULL);                                                    -- Latest #BT
                        || '~'
                        || stg_table_tbl (ln_indx).EBS_SALES_CHANNEL_CODE -- Latest #BT
                        || '~'
                        || stg_table_tbl (ln_indx).EBS_DEMAND_CLASS_CODE); -- Latest #BT
                END LOOP;

                g_progress   := 'Printing the Output....';

                fnd_file.put_line (fnd_file.LOG, g_progress);
            EXCEPTION
                WHEN OTHERS
                THEN
                    IF get_stg_disp_c%ISOPEN
                    THEN
                        CLOSE get_stg_disp_c;
                    END IF;

                    /*
                                   xxd_common_utils.record_error (
                                      p_module       => 'SO',
                                      p_org_id       => g_org_id,
                                      p_program      => 'Extract_Records_Proc',
                                      p_error_line   => SQLCODE,
                                      p_error_msg    =>    'Error while extract data '
                                                        || SUBSTR ('Error:-' || SQLERRM, 1, 499),
                                      p_created_by   => g_user_id,
                                      p_request_id   => g_conc_request_id);
                    */
                    g_progress   := 'CaughtException while display of data';

                    fnd_file.put_line (fnd_file.LOG, g_progress || SQLERRM);
            END;
        END LOOP;

        IF get_stg_disp_c%ISOPEN
        THEN
            CLOSE get_stg_disp_c;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            /*
                     xxd_common_utils.record_error (
                        p_module       => 'SO',
                        p_org_id       => g_org_id,
                        p_program      => 'Extract_Records_Proc',
                        p_error_line   => SQLCODE,
                        p_error_msg    =>    'Error while extract data '
                                          || SUBSTR ('Error:-' || SQLERRM, 1, 499),
                        p_created_by   => g_user_id,
                        p_request_id   => g_conc_request_id);
            */
            g_progress   :=
                'CaughtException while display of data in the Main block';

            fnd_file.put_line (fnd_file.LOG, g_progress || SQLERRM);
    END display_quantity_proc;

    /*-==============================================================================+
    |--  PROCEDURE NAME :  Display_Price_Proc                                        |
    |--  DESCRIPTION    :  Procedure to display the output Aggregated by Price.      |
    |--  Parameters     :  NA                                                        |
    +--==============================================================================*/

    PROCEDURE display_price_proc
    AS
        CURSOR get_stg_disp_c IS
              SELECT group_sales_date, AVG (price) avg_price, DM_ITEM_CODE,
                     DM_ORG_CODE, DM_SITE_CODE, EBS_SALES_CHANNEL_CODE,
                     EBS_DEMAND_CLASS_CODE
                FROM XXD_DEMANTRA_STG_IFACE_T
            GROUP BY group_sales_date, DM_ITEM_CODE, DM_ORG_CODE,
                     DM_SITE_CODE, EBS_SALES_CHANNEL_CODE, EBS_DEMAND_CLASS_CODE;

        TYPE stg_table_type IS TABLE OF get_stg_disp_c%ROWTYPE
            INDEX BY BINARY_INTEGER;

        stg_table_tbl   stg_table_type;
    BEGIN
        g_progress   := 'Display  data from the staging table';

        fnd_file.put_line (fnd_file.LOG, g_progress);

        OPEN get_stg_disp_c;

        LOOP
            FETCH get_stg_disp_c
                BULK COLLECT INTO stg_table_tbl
                LIMIT g_limit;

            EXIT WHEN stg_table_tbl.COUNT = 0;

            BEGIN
                IF g_debug = 'Y'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Total no of records fetched :' || stg_table_tbl.COUNT);
                END IF;

                FOR ln_indx IN 1 .. stg_table_tbl.COUNT
                LOOP
                    fnd_file.put_line (
                        fnd_file.output,
                           stg_table_tbl (ln_indx).avg_price
                        || '~'
                        || stg_table_tbl (ln_indx).group_sales_date
                        || '~'
                        || stg_table_tbl (ln_indx).dm_item_code
                        || '~'
                        || stg_table_tbl (ln_indx).dm_org_code
                        || '~'
                        || stg_table_tbl (ln_indx).dm_site_code
                        --||'~'|| NULL                                                        -- Latest #BT
                        --||'~'|| NULL);                                                    -- Latest #BT
                        || '~'
                        || stg_table_tbl (ln_indx).EBS_SALES_CHANNEL_CODE -- Latest #BT
                        || '~'
                        || stg_table_tbl (ln_indx).EBS_DEMAND_CLASS_CODE); -- Latest #BT
                END LOOP;

                g_progress   := 'Printing the Output....';

                fnd_file.put_line (fnd_file.LOG, g_progress);
            EXCEPTION
                WHEN OTHERS
                THEN           -- Exception Handling for the Inner Begin/Block
                    IF get_stg_disp_c%ISOPEN
                    THEN
                        CLOSE get_stg_disp_c;
                    END IF;

                    /*
                                   xxd_common_utils.record_error (
                                      p_module       => 'SO',
                                      p_org_id       => g_org_id,
                                      p_program      => 'Extract_Records_Proc',
                                      p_error_line   => SQLCODE,
                                      p_error_msg    =>    'Error while extract data '
                                                        || SUBSTR ('Error:-' || SQLERRM, 1, 499),
                                      p_created_by   => g_user_id,
                                      p_request_id   => g_conc_request_id);
                    */
                    g_progress   := 'CaughtException while display of data';

                    fnd_file.put_line (fnd_file.LOG, g_progress || SQLERRM);
            END;
        END LOOP;

        IF get_stg_disp_c%ISOPEN
        THEN
            CLOSE get_stg_disp_c;
        END IF;
    EXCEPTION               -- Exception Handling for the Main Block/Procedure
        WHEN OTHERS
        THEN
            /*
                     xxd_common_utils.record_error (
                        p_module       => 'SO',
                        p_org_id       => g_org_id,
                        p_program      => 'Extract_Records_Proc',
                        p_error_line   => SQLCODE,
                        p_error_msg    =>    'Error while extract data '
                                          || SUBSTR ('Error:-' || SQLERRM, 1, 499),
                        p_created_by   => g_user_id,
                        p_request_id   => g_conc_request_id);
            */
            g_progress   :=
                'CaughtException while display of data in the Main block';

            fnd_file.put_line (fnd_file.LOG, g_progress || SQLERRM);
    END display_price_proc;
END XXD_CLOSED_SO_INTFACE_PKG;
/
