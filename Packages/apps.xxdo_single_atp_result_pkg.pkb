--
-- XXDO_SINGLE_ATP_RESULT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:16 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_SINGLE_ATP_RESULT_PKG"
IS
    /**********************************************************************************************
        * PACKAGE         : APPS.XXDO_SINGLE_ATP_RESULT_PKG
        * Author          : BT Technology Team
        * Created         : 30-MAR-2015
        * Program Name    :
        * Description     :
        *
        * Modification    :
        *-----------------------------------------------------------------------------------------------
        *     Date         Developer             Version     Description
        *-----------------------------------------------------------------------------------------------
        *     30-Mar-2015 BT Technology Team     V1.1         Development
        *     29-Oct-2015 BT Technology Team     V1.2         Code change on adding application
        *     06-Jan-2021 Jayarajan A. K.        v1.3         Added functions get_appl_atp, get_no_free_atp and get_bulk_atp
        *     05-Aug-2021 Jayarajan A. K.        v1.4         Modified get_bulk_atp function for CCR0009505
        *     25-Aug-2021 Jayarajan A. K.        v1.5         Modified for CCR0009520 - Performance Fix
        ************************************************************************************************/

    FUNCTION given_dclass (p_demand_class VARCHAR2, p_inventory_item_id NUMBER, p_inv_org_id NUMBER
                           -- Start modification by BT Technology Team 29-Oct-15 v1.2
                           , p_application VARCHAR2:= 'EDI'-- End modification by BT Technology Team 29-Oct-15 v1.2
                                                           )
        RETURN NUMBER
    IS
        lv_demand_class   VARCHAR2 (50) := NULL;
        ln_atp_qty        NUMBER := 0;
    BEGIN
        SELECT available_quantity
          INTO ln_atp_qty
          FROM XXD_MASTER_ATP_FULL_T xaf
         WHERE     xaf.inventory_item_id = p_inventory_item_id
               AND xaf.demand_class_code = p_demand_class
               --             AND TRUNC (AVAILABLE_DATE) = TRUNC (SYSDATE)
               AND xaf.inv_organization_id = p_inv_org_id
               -- Start modification by BT Technology Team 29-Oct-15 v1.2
               AND xaf.application = p_application
               -- End modification by BT Technology Team 29-Oct-15 v1.2
               AND ROWNUM = 1;

        RETURN ln_atp_qty;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'InException while getting ATP (given_dclass) : '
                || SQLCODE
                || SQLERRM);

            ln_atp_qty   := 0;

            RETURN ln_atp_qty;
    END given_dclass;

    -----------------------------------------------------------------------------------------------
    FUNCTION given_dclass_1 (p_demand_class VARCHAR2, p_inventory_item_id NUMBER, p_inv_org_id NUMBER
                             -- Start modification by BT Technology Team 29-Oct-15 v1.2
                             , p_application VARCHAR2:= 'RMS'-- End modification by BT Technology Team 29-Oct-15 v1.2
                                                             )
        RETURN NUMBER
    IS
        lv_demand_class   VARCHAR2 (50) := NULL;
        ln_atp_qty        NUMBER := 0;
    BEGIN
        SELECT SUM (available_quantity)
          INTO ln_atp_qty
          FROM XXD_MASTER_ATP_FULL_T xaf
         WHERE     xaf.inventory_item_id = p_inventory_item_id
               --       AND      TRUNC (AVAILABLE_DATE) = TRUNC (SYSDATE)
               AND xaf.inv_organization_id = p_inv_org_id
               -- Start modification by BT Technology Team 29-Oct-15 v1.2
               AND xaf.application = p_application
               -- End modification by BT Technology Team 29-Oct-15 v1.2
               AND (xaf.demand_class_code = p_demand_class OR xaf.demand_class_code = '-1');

        IF ln_atp_qty IS NULL
        THEN
            ln_atp_qty   := 0;
        END IF;

        RETURN ln_atp_qty;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'InException while getting ATP (given_dclass_1) : '
                || SQLCODE
                || SQLERRM);

            ln_atp_qty   := 0;

            RETURN ln_atp_qty;
    END given_dclass_1;

    -----------------------------------------------------------------------------------------------

    FUNCTION given_cust_number (p_cust_number VARCHAR2, p_inventory_item_id NUMBER, p_inv_org_id NUMBER
                                , p_application VARCHAR2)
        RETURN NUMBER
    IS
        /**********************************************************************************************
          * FUNCTION        : APPS.XXD_SINGLE_ATP_RESULT
          * Author          : BT Technology Team
          * Created         : 16-MAR-2015
          * Program Name    :
          * Description     :
          *
          * Modification    :
          *-----------------------------------------------------------------------------------------------
          *     Date         Developer             Version     Description
          *-----------------------------------------------------------------------------------------------
          *     16-Mar-2015 BT Technology Team     V1.1         Development
          *     02-JUN-2016  Sivakumar Boothathan V2            Changes per Incident : INC0297512
          ************************************************************************************************/

        lv_demand_class   VARCHAR2 (50) := NULL;
        ln_atp_qty        NUMBER := 0;
    BEGIN
        SELECT attribute13
          INTO lv_demand_class
          FROM hz_cust_accounts hza
         WHERE hza.account_number = p_cust_number;

        SELECT available_quantity
          INTO ln_atp_qty
          FROM XXD_MASTER_ATP_FULL_T xaf
         WHERE     xaf.inventory_item_id = p_inventory_item_id
               AND xaf.demand_class_code = lv_demand_class
               --             AND TRUNC (AVAILABLE_DATE) = TRUNC (SYSDATE)
               AND xaf.inv_organization_id = p_inv_org_id
               -------------------------------------------------------------------------------
               -- Added By Sivakumar Boothathan for Incident : INC0297512, date : 06/02/2016
               -------------------------------------------------------------------------------
               AND application = p_application
               -------------------------------------------------------------------------------
               -- Added By Sivakumar Boothathan for Incident : INC0297512, date : 06/02/2016
               -------------------------------------------------------------------------------
               AND ROWNUM = 1;

        RETURN ln_atp_qty;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'InException while getting ATP (given_cust_number) : '
                || SQLCODE
                || SQLERRM);

            ln_atp_qty   := 0;

            RETURN ln_atp_qty;
    END given_cust_number;

    -- Start v1.3 changes
    FUNCTION get_appl_atp (p_store_type VARCHAR2, p_inventory_item_id NUMBER, p_inv_org_id NUMBER
                           , p_application VARCHAR2)
        RETURN NUMBER
    IS
        ln_atp_qty   NUMBER := 0;
    BEGIN
        SELECT available_quantity
          INTO ln_atp_qty
          FROM xxd_master_atp_full_t xaf
         WHERE     xaf.inventory_item_id = p_inventory_item_id
               AND NVL (xaf.store_type, '~') = NVL (p_store_type, '~')
               AND xaf.inv_organization_id = p_inv_org_id
               AND xaf.application = p_application
               AND ROWNUM = 1;

        RETURN ln_atp_qty;
    EXCEPTION
        --Start changes v1.5
        WHEN NO_DATA_FOUND
        THEN
            ln_atp_qty   := 0;
            RETURN ln_atp_qty;
        --End changes v1.5
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error in get_appl_atp for item_id: '
                || p_inventory_item_id
                || ' :: '
                || SQLCODE
                || SQLERRM);
            ln_atp_qty   := 0;
            RETURN ln_atp_qty;
    END get_appl_atp;

    FUNCTION get_no_free_atp (p_store_type          VARCHAR2,
                              p_inventory_item_id   NUMBER,
                              p_inv_org_id          NUMBER,
                              p_application1        VARCHAR2,
                              p_application2        VARCHAR2)
        RETURN NUMBER
    IS
        ln_no_free_atp   NUMBER := 0;
    BEGIN
        ln_no_free_atp   :=
              get_appl_atp (p_store_type, p_inventory_item_id, p_inv_org_id,
                            p_application1)
            - get_appl_atp (NULL, p_inventory_item_id, p_inv_org_id,
                            p_application2);

        IF ln_no_free_atp < 0
        THEN
            ln_no_free_atp   := 0;
        END IF;

        RETURN ln_no_free_atp;
    EXCEPTION
        --Start changes v1.5
        WHEN NO_DATA_FOUND
        THEN
            ln_no_free_atp   := 0;
            RETURN ln_no_free_atp;
        --End changes v1.5
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error in get_no_free_atp for item_id: '
                || p_inventory_item_id
                || ' :: '
                || SQLCODE
                || SQLERRM);
            ln_no_free_atp   := 0;
            RETURN ln_no_free_atp;
    END get_no_free_atp;

    FUNCTION get_bulk_atp (p_cust_number VARCHAR2, p_inventory_item_id NUMBER, p_inv_org_id NUMBER
                           , p_application VARCHAR2)
        RETURN NUMBER
    IS
        ln_bulk_atp        NUMBER := 0;
        ln_bulk_qty        NUMBER := 0;
        --Start changes v1.4
        ln_cust_accnt_id   NUMBER;
        lv_bulk_flag       VARCHAR2 (150);
    --End changes v1.4
    BEGIN
        ln_bulk_atp   :=
            get_appl_atp (NULL, p_inventory_item_id, p_inv_org_id,
                          p_application);

        --Start changes v1.4
        SELECT cust_account_id, attribute16
          INTO ln_cust_accnt_id, lv_bulk_flag
          FROM hz_cust_accounts hca
         WHERE hca.account_number = p_cust_number;

        IF NVL (lv_bulk_flag, 'N') = 'Y'
        THEN
            --End changes v1.4

            SELECT SUM (oola.ordered_quantity)
              INTO ln_bulk_qty
              FROM oe_order_headers_all ooha, oe_transaction_types_tl ottt, oe_order_lines_all oola
             WHERE     1 = 1
                   AND ooha.header_id = oola.header_id
                   AND ottt.transaction_type_id = ooha.order_type_id
                   AND ooha.sold_to_org_id = ln_cust_accnt_id           --v1.4
                   AND ooha.open_flag = 'Y'
                   AND ottt.language = USERENV ('LANG')
                   AND ottt.name LIKE 'Bulk%'                           --v1.4
                   AND oola.inventory_item_id = p_inventory_item_id
                   AND oola.ship_from_org_id = p_inv_org_id
                   AND oola.open_flag = 'Y'
                   AND oola.schedule_ship_date IS NOT NULL
                   AND oola.schedule_ship_date < TRUNC (SYSDATE + 1);
        --Start changes v1.4
        ELSE
            ln_bulk_qty   := 0;
        END IF;

        --End changes v1.4

        ln_bulk_atp   := NVL (ln_bulk_qty, 0) + ln_bulk_atp;

        RETURN ln_bulk_atp;
    EXCEPTION
        --Start changes v1.5
        WHEN NO_DATA_FOUND
        THEN
            RETURN ln_bulk_atp;
        --End changes v1.5
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error in get_bulk_atp for item_id: '
                || p_inventory_item_id
                || ' :: '
                || SQLCODE
                || SQLERRM);
            RETURN ln_bulk_atp;
    END get_bulk_atp;
-- End v1.3 changes

END XXDO_SINGLE_ATP_RESULT_PKG;
/
