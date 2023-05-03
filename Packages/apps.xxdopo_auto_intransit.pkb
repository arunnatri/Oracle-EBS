--
-- XXDOPO_AUTO_INTRANSIT  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:44 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOPO_AUTO_INTRANSIT"
/*
================================================================
 Created By              : BT Technology Team
 Creation Date           : 14-April-2015
 File Name               : XXDOPO_AUTO_INTRANSIT.pkb
 Incident Num            :
 Description             :
 Latest Version          : 1.0

================================================================
 Date               Version#    Name                    Remarks
================================================================
14-April-2015        1.0       BT Technology Team
11-JUN-2015          1.1       BT Technology Team     Changes ccid logic for overheads for CR#54
14-JUL-2015          1.2       BT Technology Team     Added By BT Technology Team on 14-Jul-2015 to eliminate Duplicate Journal creation
09-Sep-2015          1.3       BT Technology Team     Changes to the logic for updating sourcing rule for source PLM as per CR#54
03-Dec-2015          1.4       BT Technology Team     Attribute change for Receive/Correct transactions for Defect#749
29-Jun-2016          1.5       Bala Murugesan         Modified to correct the number of -ve entries for over shipment case;
                                                      Changes can be identified by LAST_TRANS
06-Jul-2016          1.6       Bala Murugesan         The program stops processing even when a single ASN has data issue.
                                                      Exception handling was improved to take care of this;
                                                      Changes can be identified by EXCEPTION_HANDLE

06-Jul-2016          1.6       Bala Murugesan         The program stops processing even when a single GL account is not setup
                                                      The assumption is the standard API get_ccid will return null if the account is not defined,
                                                      but it return zero. So the condition to check this is changed;
                                                      Changes can be identified by ZERO_CCID
02-May-2017          1.7       Bala Murugesan         Modified to store the unit cost elements in ASN line DFF and use them for reversal
                                                      Changes can be identified by ELEMENTS_IN_DFF
02-May-2017          1.7       Bala Murugesan         Modified to decrease the commit batch size;
                                                      Changes can be identified by COMMIT_BATCH_SIZE
07-Feb-2018          1.8       Greg Jensen            CCR0006936
22-May-2019          1.9       Aravind Kannuri        CCR0007955
25-June-2019         1.10      Greg Jensen            CCR0007979 Macau Project
10-April-2020        1.11      Greg Jensen            CCR0008582 Fix for US non costed items
28-July-2020         1.12      Greg Jensen            CCR0008704 Fix for items W OH  and W/O receipts
23-AUG-2021          2.0       Srinath Siricilla      CCR0009441
29-APR-2022          2.1       Srinath Siricilla      CCR0009984
This is an Deckers Purchasing Intransit Accrual program to create the Journals for ASN
======================================================================================
*/

AS
    lg_package_name         CONSTANT VARCHAR2 (200) := 'XXDOPO_AUTO_INTRANSIT';
    lg_je_source            CONSTANT VARCHAR2 (80) := 'In Transit';
    lg_je_category          CONSTANT VARCHAR2 (80) := 'In Transit';
    g_intransit_context              VARCHAR2 (100) := 'In-Transit Journal';
    g_reverse_intransit_context      VARCHAR2 (100)
                                         := 'Reverse In-Transit Journal'; --CCR0007979 (removed region)
    g_reverse_corrected_context      VARCHAR2 (100)
                                         := 'Correct In-Transit Journal'; --CCR0007979(removed region)
    g_reverse_cancelled_context      VARCHAR2 (100)
                                         := 'Cancel In-Transit Journal'; --CCR0007979(removed region)
    g_adjustment_intransit_context   VARCHAR2 (100)
                                         := 'Adjustment In-Transit Journal'; -- CCR0006936,-CCR0007979(removed region)
    g_batch_name                     VARCHAR2 (100)
        := 'Subelement lntransit ' || TO_CHAR (SYSDATE, 'YYYYMMDD-HH24MISS');
    g_reverse_batch_name             VARCHAR2 (100)
        :=    'Subelement Reverse lntransit '
           || TO_CHAR (SYSDATE, 'YYYYMMDD-HH24MISS');
    g_rev_can_batch_name             VARCHAR2 (100)
        :=    'Subelement Reverse Cancelled '
           || TO_CHAR (SYSDATE, 'YYYYMMDD-HH24MISS');
    g_rev_cor_batch_name             VARCHAR2 (100)
        :=    'Subelement Reverse Corrected '
           || TO_CHAR (SYSDATE, 'YYYYMMDD-HH24MISS');
    g_adj_batch_name                 VARCHAR2 (100)
        :=    'Subelement Adjustment lntransit '
           || TO_CHAR (SYSDATE, 'YYYYMMDD-HH24MISS');             --CCR0006936
    -- COMMIT_BATCH_SIZE - Start
    g_commit_batch_size              NUMBER := 200;

    -- COMMIT_BATCH_SIZE - End

    --Begin CCR0007979
    FUNCTION Check_intransit_region (pv_region IN VARCHAR)
        RETURN BOOLEAN
    IS
        n_count   NUMBER;
    BEGIN
        SELECT COUNT (*)
          INTO n_count
          FROM hr_all_organization_units
         WHERE attribute7 = pv_region;

        RETURN n_count > 0;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END;

    FUNCTION get_intransit_region (pv_ou IN NUMBER)
        RETURN VARCHAR
    IS
        v_region   VARCHAR2 (10);
    BEGIN
        SELECT attribute7
          INTO v_region
          FROM hr_all_organization_units
         WHERE organization_id = pv_ou;

        RETURN v_region;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    --End CCR0007979


    -- Start of Change for CCR0009441

    -- Commented as per CCR0009984

    /*
      FUNCTION get_duty_valid_flag_fnc (pn_org_id   IN NUMBER,
            pv_element  IN VARCHAR2)
     RETURN VARCHAR2
     IS
     lv_flag VARCHAR2(10);
      BEGIN

        lv_flag := NULL;

     SELECT  ffvl.attribute3
    INTO  lv_flag
    FROM  apps.fnd_flex_value_sets ffvs,
       apps.fnd_flex_values_vl ffvl
      WHERE  1=1
    AND  ffvs.flex_value_set_name = 'XXD_INTRANSIT_OU_COST_ELE_MAP'
    AND  ffvs.flex_value_set_id = ffvl.flex_value_set_id
    AND  ffvl.enabled_flag = 'Y'
    AND  SYSDATE BETWEEN NVL(ffvl.start_date_active,SYSDATE) AND
                                  NVL(ffvl.end_date_active,SYSDATE)
        AND  ffvl.attribute1 = pn_org_id
        AND upper(ffvl.attribute2)  = upper(pv_element);

        RETURN lv_flag;

      EXCEPTION
      WHEN OTHERS
      THEN
     lv_flag := NULL;
     RETURN lv_flag;


      END get_duty_valid_flag_fnc; */

    -- Commented as per CCR0009984


    FUNCTION get_duty_valid_fnc (pn_org_id IN NUMBER, pv_element IN VARCHAR2)
        RETURN NUMBER
    IS
        --ln_flag NUMBER;
        lv_flag   VARCHAR2 (1);
    BEGIN
        --ln_flag := 0;
        lv_flag   := NULL;

        SELECT ffvl.attribute3
          INTO lv_flag
          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
         WHERE     1 = 1
               AND ffvs.flex_value_set_name = 'XXD_INTRANSIT_OU_COST_ELE_MAP'
               AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
               AND ffvl.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (ffvl.start_date_active, SYSDATE)
                               AND NVL (ffvl.end_date_active, SYSDATE)
               AND ffvl.attribute1 = pn_org_id
               AND UPPER (ffvl.attribute2) = UPPER (pv_element);

        IF lv_flag = 'Y'
        THEN
            RETURN 1;
        ELSIF lv_flag IS NULL
        THEN
            RETURN 1;
        ELSE
            RETURN 0;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            lv_flag   := NULL;
            RETURN 1;
        WHEN OTHERS
        THEN
            RETURN 0;
    END get_duty_valid_fnc;


    -- End of Change for CCR0009441


    -- End of Change

    /* Function to determine the Amount */
    FUNCTION get_amount (p_cost                  IN VARCHAR2,
                         p_organization_id       IN NUMBER,
                         p_inventory_item_id     IN NUMBER,
                         p_po_header_id          IN NUMBER,
                         p_po_line_id            IN NUMBER,
                         p_po_line_location_id   IN NUMBER)
        RETURN NUMBER
    IS
        ln_itemcost             NUMBER;
        ln_dutyrate             NUMBER;
        ln_dutyfactor           NUMBER;
        ln_ohduty               NUMBER;
        ln_ohnonduty            NUMBER;
        ln_freight_du           NUMBER;
        ln_unitprice            NUMBER;
        ln_firstsale            NUMBER;
        ln_amount               NUMBER;
        ---change for CR#54 starts
        ln_unit_selling_price   NUMBER := 0;
        ln_cst_item_cost        NUMBER := 0;
        ln_duty                 NUMBER := 0;
        ln_ohduty_rate          NUMBER := 0;
        ln_ohduty_final         NUMBER := 0;
        ln_freight_du_rate      NUMBER := 0;
        ln_freight_du_final     NUMBER := 0;
        ln_dutyrate_base        NUMBER := 0;
        ln_duty_base            NUMBER := 0;
        --Start defect 434
        ln_oh_nonduty           NUMBER := 0;
        ln_oh_nondudy_rate      NUMBER := 0;
        ln_ou_id                NUMBER;             -- Added as per CCR0009441
    --End defect 434
    --change for CR#54 ends
    BEGIN
        --fnd_file.put_line (fnd_file.LOG, ' Starting of get_amount');
        --fnd_file.put_line (fnd_file.LOG, ' Cost type : ' || p_cost);

        ln_ou_id   := NULL;

        BEGIN
            SELECT operating_unit
              INTO ln_ou_id
              FROM org_organization_definitions
             WHERE 1 = 1 AND organization_id = p_organization_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_ou_id   := NULL;
        END;

        BEGIN
            SELECT /* NVL (pll.attribute11, 0),
                    NVL (pll.attribute12, 0),
                    NVL (pll.attribute13, 0),
                    NVL (pll.attribute14, 0),
                    NVL (pl.attribute12, 0),
                    pl.unit_price * NVL (rate, 1)
               INTO ln_dutyrate,
                    ln_dutyfactor,
                    ln_ohduty,
                    ln_freight_du,
                    ln_firstsale,
                    ln_unitprice*/
                                                         --commented for CR#54

                                                     --change for CR#54 starts
                    get_duty_valid_fnc (ln_ou_id, 'DUTY')
                  * NVL (pll.attribute11,
                         xxdoget_item_cost ('DUTY', p_organization_id, p_inventory_item_id
                                            , 'Y')),
                    get_duty_valid_fnc (ln_ou_id, 'DUTY')
                  * NVL (
                        pll.attribute12,
                        NVL (
                            (SELECT MAX (additional_duty)
                               FROM xxdo.xxdo_invval_duty_cost
                              WHERE     inventory_org = p_organization_id
                                    AND inventory_item_id = p_inventory_item_id
                                    AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                    NVL (
                                                                        duty_start_date,
                                                                        SYSDATE))
                                                            AND TRUNC (
                                                                    NVL (
                                                                        duty_end_date,
                                                                        SYSDATE))),
                            0)),
                    get_duty_valid_fnc (ln_ou_id, 'OH DUTY')
                  * NVL (pll.attribute13,
                         xxdoget_item_cost ('OH DUTY', p_organization_id, p_inventory_item_id
                                            , 'Y')),
                    get_duty_valid_fnc (ln_ou_id, 'FREIGHT DU')
                  * NVL (pll.attribute14,
                         xxdoget_item_cost ('FREIGHT DU', p_organization_id, p_inventory_item_id
                                            , 'Y')),
                    get_duty_valid_fnc (ln_ou_id, 'DUTY')
                  * NVL (  pll.attribute11
                         * xxdoget_item_cost ('DUTY FACTOR', p_organization_id, p_inventory_item_id
                                              , 'Y'),
                         xxdoget_item_cost ('DUTY RATE', p_organization_id, p_inventory_item_id
                                            , 'Y')),
                    get_duty_valid_fnc (ln_ou_id, 'OH DUTY')
                  * NVL (  pll.attribute13
                         * xxdoget_item_cost ('OH DUTY FACTOR', p_organization_id, p_inventory_item_id
                                              , 'Y'),
                         xxdoget_item_cost ('OH DUTY RATE', p_organization_id, p_inventory_item_id
                                            , 'Y')),
                    get_duty_valid_fnc (ln_ou_id, 'FREIGHT DU')
                  * NVL (  pll.attribute14
                         * xxdoget_item_cost ('FREIGHT DU FACTOR', p_organization_id, p_inventory_item_id
                                              , 'Y'),
                         xxdoget_item_cost ('FREIGHT DU RATE', p_organization_id, p_inventory_item_id
                                            , 'Y')),
                    get_duty_valid_fnc (ln_ou_id, 'DUTY')
                  * xxdoget_item_cost ('DUTY RATE', p_organization_id, p_inventory_item_id
                                       , 'Y'),
                    get_duty_valid_fnc (ln_ou_id, 'DUTY')
                  * xxdoget_item_cost ('DUTY', p_organization_id, p_inventory_item_id
                                       , 'Y'),
                    --Start defect 434
                    get_duty_valid_fnc (ln_ou_id, 'OH NONDUTY')
                  * xxdoget_item_cost ('OH NONDUTY', p_organization_id, p_inventory_item_id
                                       , 'Y'),
                    get_duty_valid_fnc (ln_ou_id, 'OH NONDUTY')
                  * xxdoget_item_cost ('OH NONDUTY RATE', p_organization_id, p_inventory_item_id
                                       , 'Y'),
                  xxdoget_item_cost ('ITEMCOST', p_organization_id, p_inventory_item_id
                                     , 'Y'),
                  --End defect 434
                  pl.attribute12
                      first_sale,
                  pl.unit_price
             INTO ln_duty, ln_dutyfactor, ln_ohduty, ln_freight_du,
                         ln_dutyrate, ln_ohduty_rate, ln_freight_du_rate,
                         ln_dutyrate_base, ln_duty_base, --Start defect 434
                                                         ln_oh_nonduty,
                         ln_oh_nondudy_rate, ln_cst_item_cost, --End defect 434
                                                               ln_firstsale,
                         ln_unitprice
             --change for CR#54 ends
             FROM po_headers_all ph, po_lines_all pl, po_line_locations_all pll
            WHERE     1 = 1
                  AND ph.po_header_id = pl.po_header_id
                  AND pl.po_line_id = pll.po_line_id
                  AND pl.po_line_id = p_po_line_id
                  AND pll.line_location_id = p_po_line_location_id
                  AND pl.item_id = p_inventory_item_id
                  AND ph.po_header_id = p_po_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_dutyrate          := 0;
                ln_dutyfactor        := 0;
                ln_ohduty            := 0;
                ln_freight_du        := 0;
                ln_firstsale         := 0;
                ln_unitprice         := 0;
                --Start defect 434
                ln_oh_nonduty        := 0;
                ln_oh_nondudy_rate   := 0;
                ln_cst_item_cost     := 0;
        --End defect 434
        END;

        IF p_cost = 'In Transit' OR p_cost = 'Factory Cost'
        THEN
            ln_itemcost   := ln_unitprice;
            fnd_file.put_line (fnd_file.LOG, ln_itemcost);
            RETURN ln_itemcost;
        ELSIF p_cost = 'DUTY'
        THEN
            /* ln_itemcost :=
                (  ln_dutyrate
                 * (ln_unitprice + ln_dutyfactor + ln_ohduty + ln_freight_du));*/
            --commented for CR#54

            --change for CR#54 starts
            ln_ohduty_final   :=
                NVL ((ln_ohduty_rate * NVL (ln_firstsale, ln_unitprice)),
                     NVL (ln_ohduty, 0));
            ln_freight_du_final   :=
                NVL ((ln_freight_du_rate * NVL (ln_firstsale, ln_unitprice)),
                     NVL (ln_freight_du, 0));
            --CCR0007979 change position of ") and add round
            ln_itemcost   :=
                NVL (
                    ROUND (
                        (ln_dutyrate * (NVL (ln_firstsale, ln_unitprice) --CCR0007979
                                                                         + ln_dutyfactor + ln_ohduty_final + ln_freight_du_final)), -- modified or UAT issue in duty mar14 2020 GJ
                        2),
                    NVL (ln_duty, 0));                            --CCR0007979
            --change for CR#54 ends
            --fnd_file.put_line (fnd_file.LOG, ln_itemcost);
            RETURN ROUND (ln_itemcost, 2);                        --CCR0007979
        ELSIF p_cost = 'FREIGHT'
        THEN
            ln_itemcost   :=
                  get_duty_valid_fnc (ln_ou_id, 'FREIGHT')
                * xxdoget_item_cost ('FREIGHT', p_organization_id, p_inventory_item_id
                                     , 'Y');
            -- fnd_file.put_line (fnd_file.LOG, ln_itemcost);
            RETURN ROUND (ln_itemcost, 2);                        --CCR0007979
        ELSIF p_cost = 'FREIGHT DU'
        THEN
            --Start defect 434
            --Start CCR0008582
            IF NVL (xxdoget_item_cost ('FREIGHT DU FACTOR', p_organization_id, p_inventory_item_id
                                       , 'Y'),
                    0) = 0
            THEN
                ln_itemcost   :=
                      get_duty_valid_fnc (ln_ou_id, 'FREIGHT DU')
                    * xxdoget_item_cost ('FREIGHT DU', p_organization_id, p_inventory_item_id
                                         , 'Y');
            ELSE
                ln_itemcost   :=
                      get_duty_valid_fnc (ln_ou_id, 'FREIGHT DU')
                    * NVL (xxdoget_item_cost ('FREIGHT DU RATE', p_organization_id, p_inventory_item_id
                                              , 'Y'),
                           0)                                     --CCR0008704
                    * NVL (ln_firstsale, ln_unitprice);
            END IF;

            --End CCR0008582
            --End defect 434
            --fnd_file.put_line (fnd_file.LOG, ln_itemcost);
            RETURN ROUND (ln_itemcost, 2);                        --CCR0007979
        ELSIF p_cost = 'OH DUTY'
        THEN
            --Start defect 434
            --start CCR0008582
            IF NVL (xxdoget_item_cost ('OH DUTY FACTOR', p_organization_id, p_inventory_item_id
                                       , 'Y'),
                    0) = 0
            THEN
                ln_itemcost   :=
                      get_duty_valid_fnc (ln_ou_id, 'OH DUTY')
                    * xxdoget_item_cost ('OH DUTY', p_organization_id, p_inventory_item_id
                                         , 'Y');
            ELSE
                ln_itemcost   :=
                      get_duty_valid_fnc (ln_ou_id, 'OH DUTY')
                    * NVL (xxdoget_item_cost ('OH DUTY RATE', p_organization_id, p_inventory_item_id
                                              , 'Y'),
                           0)                                    ---CCR0008704
                    * NVL (ln_firstsale, ln_unitprice);
            END IF;

            --end CCR0008582
            --End defect 434
            --fnd_file.put_line (fnd_file.LOG,'OH NONDUTY item cost'|| ln_itemcost);
            RETURN ROUND (ln_itemcost, 2);                        --CCR0007979
        ELSIF p_cost = 'OH NONDUTY'
        THEN
            --Start defect 434
            --start CCR0008582
            IF NVL (xxdoget_item_cost ('OH NONDUTY FACTOR', p_organization_id, p_inventory_item_id
                                       , 'Y'),
                    0) = 0
            THEN
                ln_itemcost   :=
                      get_duty_valid_fnc (ln_ou_id, 'OH NONDUTY')
                    * xxdoget_item_cost ('OH NONDUTY', p_organization_id, p_inventory_item_id
                                         , 'Y');
            ELSE
                ln_itemcost   :=
                      get_duty_valid_fnc (ln_ou_id, 'OH NONDUTY')
                    * NVL (xxdoget_item_cost ('OH NONDUTY RATE', p_organization_id, p_inventory_item_id
                                              , 'Y'),
                           0)                                    ---CCR0008704
                    * NVL (ln_firstsale, ln_unitprice);
            END IF;

            --end CCR0008582
            --End defect 434
            --fnd_file.put_line (fnd_file.LOG, ln_itemcost);
            RETURN ROUND (ln_itemcost, 2);                        --CCR0007979
        ELSIF p_cost = 'OVERHEADS '
        THEN
            /* ln_itemcost :=
         (  ln_dutyrate
          * (ln_unitprice + ln_dutyfactor + ln_ohduty + ln_freight_du));*/
            --commented for CR#54
            --Start defect 434

            --Start defect 434
            --start CCR0008582
            IF NVL (xxdoget_item_cost ('FREIGHT DU FACTOR', p_organization_id, p_inventory_item_id
                                       , 'Y'),
                    0) = 0
            THEN
                ln_freight_du   :=
                      get_duty_valid_fnc (ln_ou_id, 'FREIGHT DU')
                    * xxdoget_item_cost ('FREIGHT DU', p_organization_id, p_inventory_item_id
                                         , 'Y');
            ELSE
                ln_freight_du   :=
                      get_duty_valid_fnc (ln_ou_id, 'FREIGHT DU')
                    * NVL (xxdoget_item_cost ('FREIGHT DU RATE', p_organization_id, p_inventory_item_id
                                              , 'Y'),
                           0)                                    ---CCR0008704
                    * NVL (ln_firstsale, ln_unitprice);
            END IF;

            --Start defect 434
            IF NVL (xxdoget_item_cost ('OH DUTY FACTOR', p_organization_id, p_inventory_item_id
                                       , 'Y'),
                    0) = 0
            THEN
                ln_ohduty   :=
                      get_duty_valid_fnc (ln_ou_id, 'OH DUTY')
                    * xxdoget_item_cost ('OH DUTY', p_organization_id, p_inventory_item_id
                                         , 'Y');
            ELSE
                ln_ohduty   :=
                      get_duty_valid_fnc (ln_ou_id, 'OH DUTY')
                    * NVL (xxdoget_item_cost ('OH DUTY RATE', p_organization_id, p_inventory_item_id
                                              , 'Y'),
                           0)                                    ---CCR0008704
                    * NVL (ln_firstsale, ln_unitprice);
            END IF;

            IF NVL (xxdoget_item_cost ('OH NONDUTY FACTOR', p_organization_id, p_inventory_item_id
                                       , 'Y'),
                    0) = 0
            THEN
                ln_oh_nonduty   :=
                      get_duty_valid_fnc (ln_ou_id, 'OH NONDUTY')
                    * xxdoget_item_cost ('OH NONDUTY', p_organization_id, p_inventory_item_id
                                         , 'Y');
            ELSE
                ln_oh_nonduty   :=
                      get_duty_valid_fnc (ln_ou_id, 'OH NONDUTY')
                    * NVL (xxdoget_item_cost ('OH NONDUTY RATE', p_organization_id, p_inventory_item_id
                                              , 'Y'),
                           0)                                    ---CCR0008704
                    * NVL (ln_firstsale, ln_unitprice);
            END IF;

            --end CCR0008582
            /*
                     IF NVL (ln_cst_item_cost, 0) > 0
                     THEN
                        ln_freight_du :=
                           xxdoget_item_cost ('FREIGHT DU',
                                              p_organization_id,
                                              p_inventory_item_id,
                                              'Y');
                        ln_oh_nonduty :=
                           xxdoget_item_cost ('OH NONDUTY',
                                              p_organization_id,
                                              p_inventory_item_id,
                                              'Y');
                        ln_ohduty :=
                           xxdoget_item_cost ('OH DUTY',
                                              p_organization_id,
                                              p_inventory_item_id,
                                              'Y');
                     ELSE
                        ln_freight_du :=
                           NVL (  xxdoget_item_cost ('FREIGHT DU RATE',
                                                     p_organization_id,
                                                     p_inventory_item_id,
                                                     'Y')
                                * NVL (ln_firstsale, ln_unitprice),
                                xxdoget_item_cost ('FREIGHT DU',
                                                   p_organization_id,
                                                   p_inventory_item_id,
                                                   'Y'));
                        ln_oh_nonduty :=
                           NVL (  xxdoget_item_cost ('OH NONDUTY RATE',
                                                     p_organization_id,
                                                     p_inventory_item_id,
                                                     'Y')
                                * NVL (ln_firstsale, ln_unitprice),
                                xxdoget_item_cost ('OH NONDUTY',
                                                   p_organization_id,
                                                   p_inventory_item_id,
                                                   'Y'));
                        ln_ohduty :=
                           NVL (  xxdoget_item_cost ('OH DUTY RATE',
                                                     p_organization_id,
                                                     p_inventory_item_id,
                                                     'Y')
                                * NVL (ln_firstsale, ln_unitprice),
                                xxdoget_item_cost ('OH DUTY',
                                                   p_organization_id,
                                                   p_inventory_item_id,
                                                   'Y'));
                     END IF;
                     */

            --End defect 434

            --change for CR#54 starts
            ln_ohduty_final   :=
                NVL ((ln_ohduty_rate * NVL (ln_firstsale, ln_unitprice)),
                     NVL (ln_ohduty, 0));
            ln_freight_du_final   :=
                NVL ((ln_freight_du_rate * NVL (ln_firstsale, ln_unitprice)),
                     NVL (ln_freight_du, 0));

            --CCR0007979 change position of ") and add round"


            ln_itemcost   :=
                  NVL (
                      ROUND (
                          (ln_dutyrate * (NVL (ln_firstsale, ln_unitprice) --CCR0007979
                                                                           + ln_dutyfactor + ln_ohduty_final + ln_freight_du_final)), -- modified or UAT issue in duty mar14 2020 GJ
                          2),
                      ROUND (NVL (ln_duty, 0), 2))                --CCR0007979
                --change for CR#54 ends
                +   get_duty_valid_fnc (ln_ou_id, 'FREIGHT')
                  * ROUND (xxdoget_item_cost ('FREIGHT',          --CCR0007979
                                                         p_organization_id, p_inventory_item_id
                                              , 'Y'),
                           2)
                --Start defect 434
                + ROUND (ln_freight_du, 2)
                + ROUND (ln_ohduty, 2)
                + ROUND (ln_oh_nonduty, 2);
            --End defect 434
            --fnd_file.put_line (fnd_file.LOG, ln_itemcost);
            RETURN ln_itemcost;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Others Exception in get_amount function,so returning zero for item - '
                || p_inventory_item_id
                || '  '
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
            RETURN 0;
    END get_amount;

    /* Function to determine the Code Combination Id */
    FUNCTION get_ccid (p_segments IN VARCHAR2, p_coc_id IN NUMBER, --added as per CR#54
                                                                   p_organization_id IN NUMBER
                       , p_inventory_item_num IN NUMBER)
        RETURN NUMBER
    IS
        ln_ccid             NUMBER;
        lc_segment1         NUMBER;
        lc_segment2         NUMBER;
        lc_segment3         NUMBER;
        lc_segment4         NUMBER;
        lc_segment5         NUMBER;
        lc_segment6         NUMBER;
        lc_segment7         NUMBER;
        lc_segment8         NUMBER;
        lc_char_of_acc_id   NUMBER;
    BEGIN
        /*SELECT chart_of_accounts_id
          INTO lc_char_of_acc_id
          FROM gl_sets_of_books
         WHERE set_of_books_id = fnd_profile.VALUE ('GL_SET_OF_BKS_ID');*/
        --commented as per CR#54

        lc_char_of_acc_id   := p_coc_id;                  --added as per CR#54

        SELECT GCC.SEGMENT2
          INTO lc_segment2
          FROM MTL_SYSTEM_ITEMS_B MSIB, GL_CODE_COMBINATIONS GCC
         WHERE     MSIB.INVENTORY_ITEM_ID = p_inventory_item_Num
               AND MSIB.ORGANIZATION_ID = p_organization_id
               AND GCC.CODE_COMBINATION_ID = COST_OF_SALES_ACCOUNT;



        IF p_segments IN ('In Transit', 'OVERHEADS ')
        THEN
            SELECT GCC.SEGMENT1, GCC.SEGMENT3, GCC.SEGMENT4,
                   GCC.SEGMENT5, GCC.SEGMENT6, GCC.SEGMENT7,
                   GCC.SEGMENT8
              INTO lc_segment1, lc_segment3, lc_segment4, lc_segment5,
                              lc_segment6, lc_segment7, lc_segment8
              FROM RCV_PARAMETERS RP, GL_CODE_COMBINATIONS GCC
             WHERE     ORGANIZATION_ID = p_organization_id
                   AND RP.CLEARING_ACCOUNT_ID = GCC.CODE_COMBINATION_ID;



            ln_ccid   :=
                fnd_flex_ext.get_ccid (
                    'SQLGL',
                    'GL#',
                    lc_char_of_acc_id,
                    NULL,
                       lc_segment1
                    || '.'
                    || lc_segment2
                    || '.'
                    || lc_segment3
                    || '.'
                    || lc_segment4
                    || '.'
                    || lc_segment5
                    || '.'
                    || lc_segment6
                    || '.'
                    || lc_segment7
                    || '.'
                    || lc_segment8);
            RETURN ln_ccid;
        ELSIF p_segments = 'Factory Cost'
        THEN
            SELECT GCC.SEGMENT1, GCC.SEGMENT3, GCC.SEGMENT4,
                   GCC.SEGMENT5, GCC.SEGMENT6, GCC.SEGMENT7,
                   GCC.SEGMENT8
              INTO lc_segment1, lc_segment3, lc_segment4, lc_segment5,
                              lc_segment6, lc_segment7, lc_segment8
              FROM MTL_PARAMETERS MP, GL_CODE_COMBINATIONS GCC
             WHERE     MP.ORGANIZATION_ID = p_organization_id
                   AND GCC.CODE_COMBINATION_ID = MP.AP_ACCRUAL_ACCOUNT;


            ln_ccid   :=
                fnd_flex_ext.get_ccid (
                    'SQLGL',
                    'GL#',
                    lc_char_of_acc_id,
                    NULL,
                       lc_segment1
                    || '.'
                    || lc_segment2
                    || '.'
                    || lc_segment3
                    || '.'
                    || lc_segment4
                    || '.'
                    || lc_segment5
                    || '.'
                    || lc_segment6
                    || '.'
                    || lc_segment7
                    || '.'
                    || lc_segment8);
            RETURN ln_ccid;
        ELSIF p_segments = 'DUTY'
        THEN
            -- Start Changes by BT Technology Team on 11-JUN-2015 for CR 54#
            /*SELECT ABSORPTION_ACCOUNT
              INTO ln_ccid
              FROM BOM_RESOURCES_V
             WHERE     ORGANIZATION_ID = p_organization_id
                   AND RESOURCE_CODE = 'DUTY';*/

            SELECT GCC.SEGMENT1, GCC.SEGMENT3, GCC.SEGMENT4,
                   GCC.SEGMENT5, GCC.SEGMENT6, GCC.SEGMENT7,
                   GCC.SEGMENT8
              INTO lc_segment1, lc_segment3, lc_segment4, lc_segment5,
                              lc_segment6, lc_segment7, lc_segment8
              FROM BOM_RESOURCES_V br, gl_code_combinations gcc
             WHERE     br.ORGANIZATION_ID = p_organization_id
                   AND br.RESOURCE_CODE = 'DUTY'
                   AND br.ABSORPTION_ACCOUNT = gcc.CODE_COMBINATION_ID;


            ln_ccid   :=
                fnd_flex_ext.get_ccid (
                    'SQLGL',
                    'GL#',
                    lc_char_of_acc_id,
                    NULL,
                       lc_segment1
                    || '.'
                    || lc_segment2
                    || '.'
                    || lc_segment3
                    || '.'
                    || lc_segment4
                    || '.'
                    || lc_segment5
                    || '.'
                    || lc_segment6
                    || '.'
                    || lc_segment7
                    || '.'
                    || lc_segment8);

            -- End Changes by BT Technology Team on 11-JUN-2015 for CR 54#

            RETURN ln_ccid;
        ELSIF p_segments = 'FREIGHT'
        THEN
            -- Start Changes by BT Technology Team on 11-JUN-2015 for CR 54#
            /*SELECT ABSORPTION_ACCOUNT
              INTO ln_ccid
              FROM BOM_RESOURCES_V
             WHERE     ORGANIZATION_ID = p_organization_id
                   AND RESOURCE_CODE = 'FREIGHT';*/

            SELECT GCC.SEGMENT1, GCC.SEGMENT3, GCC.SEGMENT4,
                   GCC.SEGMENT5, GCC.SEGMENT6, GCC.SEGMENT7,
                   GCC.SEGMENT8
              INTO lc_segment1, lc_segment3, lc_segment4, lc_segment5,
                              lc_segment6, lc_segment7, lc_segment8
              FROM BOM_RESOURCES_V br, gl_code_combinations gcc
             WHERE     br.ORGANIZATION_ID = p_organization_id
                   AND br.RESOURCE_CODE = 'FREIGHT'
                   AND br.ABSORPTION_ACCOUNT = gcc.CODE_COMBINATION_ID;


            ln_ccid   :=
                fnd_flex_ext.get_ccid (
                    'SQLGL',
                    'GL#',
                    lc_char_of_acc_id,
                    NULL,
                       lc_segment1
                    || '.'
                    || lc_segment2
                    || '.'
                    || lc_segment3
                    || '.'
                    || lc_segment4
                    || '.'
                    || lc_segment5
                    || '.'
                    || lc_segment6
                    || '.'
                    || lc_segment7
                    || '.'
                    || lc_segment8);

            -- End Changes by BT Technology Team on 11-JUN-2015 for CR 54

            RETURN ln_ccid;
        ELSIF p_segments = 'FREIGHT DU'
        THEN
            -- Start Changes by BT Technology Team on 11-JUN-2015 for CR 54
            /*SELECT ABSORPTION_ACCOUNT
              INTO ln_ccid
              FROM BOM_RESOURCES_V
             WHERE     ORGANIZATION_ID = p_organization_id
                   AND RESOURCE_CODE = 'FREIGHT DU';*/

            SELECT GCC.SEGMENT1, GCC.SEGMENT3, GCC.SEGMENT4,
                   GCC.SEGMENT5, GCC.SEGMENT6, GCC.SEGMENT7,
                   GCC.SEGMENT8
              INTO lc_segment1, lc_segment3, lc_segment4, lc_segment5,
                              lc_segment6, lc_segment7, lc_segment8
              FROM BOM_RESOURCES_V br, gl_code_combinations gcc
             WHERE     br.ORGANIZATION_ID = p_organization_id
                   AND br.RESOURCE_CODE = 'FREIGHT DU'
                   AND br.ABSORPTION_ACCOUNT = gcc.CODE_COMBINATION_ID;


            ln_ccid   :=
                fnd_flex_ext.get_ccid (
                    'SQLGL',
                    'GL#',
                    lc_char_of_acc_id,
                    NULL,
                       lc_segment1
                    || '.'
                    || lc_segment2
                    || '.'
                    || lc_segment3
                    || '.'
                    || lc_segment4
                    || '.'
                    || lc_segment5
                    || '.'
                    || lc_segment6
                    || '.'
                    || lc_segment7
                    || '.'
                    || lc_segment8);

            -- End Changes by BT Technology Team on 11-JUN-2015 for CR 54

            RETURN ln_ccid;
        ELSIF p_segments = 'OH DUTY'
        THEN
            -- Start Changes by BT Technology Team on 11-JUN-2015 for CR 54
            /*SELECT ABSORPTION_ACCOUNT
              INTO ln_ccid
              FROM BOM_RESOURCES_V
             WHERE     ORGANIZATION_ID = p_organization_id
                   AND RESOURCE_CODE = 'OH DUTY';*/

            SELECT GCC.SEGMENT1, GCC.SEGMENT3, GCC.SEGMENT4,
                   GCC.SEGMENT5, GCC.SEGMENT6, GCC.SEGMENT7,
                   GCC.SEGMENT8
              INTO lc_segment1, lc_segment3, lc_segment4, lc_segment5,
                              lc_segment6, lc_segment7, lc_segment8
              FROM BOM_RESOURCES_V br, gl_code_combinations gcc
             WHERE     br.ORGANIZATION_ID = p_organization_id
                   AND br.RESOURCE_CODE = 'OH DUTY'
                   AND br.ABSORPTION_ACCOUNT = gcc.CODE_COMBINATION_ID;


            ln_ccid   :=
                fnd_flex_ext.get_ccid (
                    'SQLGL',
                    'GL#',
                    lc_char_of_acc_id,
                    NULL,
                       lc_segment1
                    || '.'
                    || lc_segment2
                    || '.'
                    || lc_segment3
                    || '.'
                    || lc_segment4
                    || '.'
                    || lc_segment5
                    || '.'
                    || lc_segment6
                    || '.'
                    || lc_segment7
                    || '.'
                    || lc_segment8);

            -- End Changes by BT Technology Team on 11-JUN-2015 for CR 54

            RETURN ln_ccid;
        ELSIF p_segments = 'OH NONDUTY'
        THEN
            -- Start Changes by BT Technology Team on 11-JUN-2015 for CR 54
            /*SELECT ABSORPTION_ACCOUNT
              INTO ln_ccid
              FROM BOM_RESOURCES_V
             WHERE     ORGANIZATION_ID = p_organization_id
                   AND RESOURCE_CODE = 'OH NONDUTY';*/

            SELECT GCC.SEGMENT1, GCC.SEGMENT3, GCC.SEGMENT4,
                   GCC.SEGMENT5, GCC.SEGMENT6, GCC.SEGMENT7,
                   GCC.SEGMENT8
              INTO lc_segment1, lc_segment3, lc_segment4, lc_segment5,
                              lc_segment6, lc_segment7, lc_segment8
              FROM BOM_RESOURCES_V br, gl_code_combinations gcc
             WHERE     br.ORGANIZATION_ID = p_organization_id
                   AND br.RESOURCE_CODE = 'OH NONDUTY'
                   AND br.ABSORPTION_ACCOUNT = gcc.CODE_COMBINATION_ID;


            ln_ccid   :=
                fnd_flex_ext.get_ccid (
                    'SQLGL',
                    'GL#',
                    lc_char_of_acc_id,
                    NULL,
                       lc_segment1
                    || '.'
                    || lc_segment2
                    || '.'
                    || lc_segment3
                    || '.'
                    || lc_segment4
                    || '.'
                    || lc_segment5
                    || '.'
                    || lc_segment6
                    || '.'
                    || lc_segment7
                    || '.'
                    || lc_segment8);

            -- End Changes by BT Technology Team on 11-JUN-2015 for CR 54

            RETURN ln_ccid;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Others Exception in get_ccid function,so returning null for item - '
                || p_inventory_item_num
                || '  '
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());

            RETURN NULL;
    END get_ccid;

    --START Added as per CCR0007955
    --To determine the CCID Segments even CCID IS NULL
    PROCEDURE get_ccid_segments (p_segments IN VARCHAR2, p_coc_id IN NUMBER, p_organization_id IN NUMBER, p_inventory_item_num IN NUMBER, p_segment1 OUT VARCHAR2, p_segment2 OUT VARCHAR2, p_segment3 OUT VARCHAR2, p_segment4 OUT VARCHAR2, p_segment5 OUT VARCHAR2, p_segment6 OUT VARCHAR2, p_segment7 OUT VARCHAR2, p_segment8 OUT VARCHAR2
                                 , p_ccid OUT NUMBER)
    IS
        ln_ccid             NUMBER;
        lc_segment1         NUMBER;
        lc_segment2         NUMBER;
        lc_segment3         NUMBER;
        lc_segment4         NUMBER;
        lc_segment5         NUMBER;
        lc_segment6         NUMBER;
        lc_segment7         NUMBER;
        lc_segment8         NUMBER;
        lc_char_of_acc_id   NUMBER;
    BEGIN
        lc_char_of_acc_id   := p_coc_id;                  --added as per CR#54

        SELECT GCC.SEGMENT2
          INTO lc_segment2
          FROM MTL_SYSTEM_ITEMS_B MSIB, GL_CODE_COMBINATIONS GCC
         WHERE     MSIB.INVENTORY_ITEM_ID = p_inventory_item_Num
               AND MSIB.ORGANIZATION_ID = p_organization_id
               AND GCC.CODE_COMBINATION_ID = COST_OF_SALES_ACCOUNT;

        IF p_segments IN ('In Transit', 'OVERHEADS ')
        THEN
            SELECT GCC.SEGMENT1, GCC.SEGMENT3, GCC.SEGMENT4,
                   GCC.SEGMENT5, GCC.SEGMENT6, GCC.SEGMENT7,
                   GCC.SEGMENT8
              INTO lc_segment1, lc_segment3, lc_segment4, lc_segment5,
                              lc_segment6, lc_segment7, lc_segment8
              FROM RCV_PARAMETERS RP, GL_CODE_COMBINATIONS GCC
             WHERE     ORGANIZATION_ID = p_organization_id
                   AND RP.CLEARING_ACCOUNT_ID = GCC.CODE_COMBINATION_ID;

            ln_ccid   :=
                fnd_flex_ext.get_ccid (
                    'SQLGL',
                    'GL#',
                    lc_char_of_acc_id,
                    NULL,
                       lc_segment1
                    || '.'
                    || lc_segment2
                    || '.'
                    || lc_segment3
                    || '.'
                    || lc_segment4
                    || '.'
                    || lc_segment5
                    || '.'
                    || lc_segment6
                    || '.'
                    || lc_segment7
                    || '.'
                    || lc_segment8);
        ELSIF p_segments = 'Factory Cost'
        THEN
            SELECT GCC.SEGMENT1, GCC.SEGMENT3, GCC.SEGMENT4,
                   GCC.SEGMENT5, GCC.SEGMENT6, GCC.SEGMENT7,
                   GCC.SEGMENT8
              INTO lc_segment1, lc_segment3, lc_segment4, lc_segment5,
                              lc_segment6, lc_segment7, lc_segment8
              FROM MTL_PARAMETERS MP, GL_CODE_COMBINATIONS GCC
             WHERE     MP.ORGANIZATION_ID = p_organization_id
                   AND GCC.CODE_COMBINATION_ID = MP.AP_ACCRUAL_ACCOUNT;

            ln_ccid   :=
                fnd_flex_ext.get_ccid (
                    'SQLGL',
                    'GL#',
                    lc_char_of_acc_id,
                    NULL,
                       lc_segment1
                    || '.'
                    || lc_segment2
                    || '.'
                    || lc_segment3
                    || '.'
                    || lc_segment4
                    || '.'
                    || lc_segment5
                    || '.'
                    || lc_segment6
                    || '.'
                    || lc_segment7
                    || '.'
                    || lc_segment8);
        ELSIF p_segments = 'DUTY'
        THEN
            SELECT GCC.SEGMENT1, GCC.SEGMENT3, GCC.SEGMENT4,
                   GCC.SEGMENT5, GCC.SEGMENT6, GCC.SEGMENT7,
                   GCC.SEGMENT8
              INTO lc_segment1, lc_segment3, lc_segment4, lc_segment5,
                              lc_segment6, lc_segment7, lc_segment8
              FROM BOM_RESOURCES_V br, gl_code_combinations gcc
             WHERE     br.ORGANIZATION_ID = p_organization_id
                   AND br.RESOURCE_CODE = 'DUTY'
                   AND br.ABSORPTION_ACCOUNT = gcc.CODE_COMBINATION_ID;

            ln_ccid   :=
                fnd_flex_ext.get_ccid (
                    'SQLGL',
                    'GL#',
                    lc_char_of_acc_id,
                    NULL,
                       lc_segment1
                    || '.'
                    || lc_segment2
                    || '.'
                    || lc_segment3
                    || '.'
                    || lc_segment4
                    || '.'
                    || lc_segment5
                    || '.'
                    || lc_segment6
                    || '.'
                    || lc_segment7
                    || '.'
                    || lc_segment8);
        ELSIF p_segments = 'FREIGHT'
        THEN
            SELECT GCC.SEGMENT1, GCC.SEGMENT3, GCC.SEGMENT4,
                   GCC.SEGMENT5, GCC.SEGMENT6, GCC.SEGMENT7,
                   GCC.SEGMENT8
              INTO lc_segment1, lc_segment3, lc_segment4, lc_segment5,
                              lc_segment6, lc_segment7, lc_segment8
              FROM BOM_RESOURCES_V br, gl_code_combinations gcc
             WHERE     br.ORGANIZATION_ID = p_organization_id
                   AND br.RESOURCE_CODE = 'FREIGHT'
                   AND br.ABSORPTION_ACCOUNT = gcc.CODE_COMBINATION_ID;

            ln_ccid   :=
                fnd_flex_ext.get_ccid (
                    'SQLGL',
                    'GL#',
                    lc_char_of_acc_id,
                    NULL,
                       lc_segment1
                    || '.'
                    || lc_segment2
                    || '.'
                    || lc_segment3
                    || '.'
                    || lc_segment4
                    || '.'
                    || lc_segment5
                    || '.'
                    || lc_segment6
                    || '.'
                    || lc_segment7
                    || '.'
                    || lc_segment8);
        ELSIF p_segments = 'FREIGHT DU'
        THEN
            SELECT GCC.SEGMENT1, GCC.SEGMENT3, GCC.SEGMENT4,
                   GCC.SEGMENT5, GCC.SEGMENT6, GCC.SEGMENT7,
                   GCC.SEGMENT8
              INTO lc_segment1, lc_segment3, lc_segment4, lc_segment5,
                              lc_segment6, lc_segment7, lc_segment8
              FROM BOM_RESOURCES_V br, gl_code_combinations gcc
             WHERE     br.ORGANIZATION_ID = p_organization_id
                   AND br.RESOURCE_CODE = 'FREIGHT DU'
                   AND br.ABSORPTION_ACCOUNT = gcc.CODE_COMBINATION_ID;

            ln_ccid   :=
                fnd_flex_ext.get_ccid (
                    'SQLGL',
                    'GL#',
                    lc_char_of_acc_id,
                    NULL,
                       lc_segment1
                    || '.'
                    || lc_segment2
                    || '.'
                    || lc_segment3
                    || '.'
                    || lc_segment4
                    || '.'
                    || lc_segment5
                    || '.'
                    || lc_segment6
                    || '.'
                    || lc_segment7
                    || '.'
                    || lc_segment8);
        ELSIF p_segments = 'OH DUTY'
        THEN
            SELECT GCC.SEGMENT1, GCC.SEGMENT3, GCC.SEGMENT4,
                   GCC.SEGMENT5, GCC.SEGMENT6, GCC.SEGMENT7,
                   GCC.SEGMENT8
              INTO lc_segment1, lc_segment3, lc_segment4, lc_segment5,
                              lc_segment6, lc_segment7, lc_segment8
              FROM BOM_RESOURCES_V br, gl_code_combinations gcc
             WHERE     br.ORGANIZATION_ID = p_organization_id
                   AND br.RESOURCE_CODE = 'OH DUTY'
                   AND br.ABSORPTION_ACCOUNT = gcc.CODE_COMBINATION_ID;

            ln_ccid   :=
                fnd_flex_ext.get_ccid (
                    'SQLGL',
                    'GL#',
                    lc_char_of_acc_id,
                    NULL,
                       lc_segment1
                    || '.'
                    || lc_segment2
                    || '.'
                    || lc_segment3
                    || '.'
                    || lc_segment4
                    || '.'
                    || lc_segment5
                    || '.'
                    || lc_segment6
                    || '.'
                    || lc_segment7
                    || '.'
                    || lc_segment8);
        ELSIF p_segments = 'OH NONDUTY'
        THEN
            SELECT GCC.SEGMENT1, GCC.SEGMENT3, GCC.SEGMENT4,
                   GCC.SEGMENT5, GCC.SEGMENT6, GCC.SEGMENT7,
                   GCC.SEGMENT8
              INTO lc_segment1, lc_segment3, lc_segment4, lc_segment5,
                              lc_segment6, lc_segment7, lc_segment8
              FROM BOM_RESOURCES_V br, gl_code_combinations gcc
             WHERE     br.ORGANIZATION_ID = p_organization_id
                   AND br.RESOURCE_CODE = 'OH NONDUTY'
                   AND br.ABSORPTION_ACCOUNT = gcc.CODE_COMBINATION_ID;

            ln_ccid   :=
                fnd_flex_ext.get_ccid (
                    'SQLGL',
                    'GL#',
                    lc_char_of_acc_id,
                    NULL,
                       lc_segment1
                    || '.'
                    || lc_segment2
                    || '.'
                    || lc_segment3
                    || '.'
                    || lc_segment4
                    || '.'
                    || lc_segment5
                    || '.'
                    || lc_segment6
                    || '.'
                    || lc_segment7
                    || '.'
                    || lc_segment8);
        END IF;

        --Assigning to OUT Vairables
        p_segment1          := lc_segment1;
        p_segment2          := lc_segment2;
        p_segment3          := lc_segment3;
        p_segment4          := lc_segment4;
        p_segment5          := lc_segment5;
        p_segment6          := lc_segment6;
        p_segment7          := lc_segment7;
        p_segment8          := lc_segment8;
        p_ccid              := ln_ccid;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_segment1   := NULL;
            p_segment2   := NULL;
            p_segment3   := NULL;
            p_segment4   := NULL;
            p_segment5   := NULL;
            p_segment6   := NULL;
            p_segment7   := NULL;
            p_segment8   := NULL;
            p_ccid       := 0;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Others Exception in get_ccid_segments procedure,so returning null for item - '
                || p_inventory_item_num
                || '  '
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END get_ccid_segments;

    --END Added as per CCR0007955

    PROCEDURE insert_into_inteface (p_org_id             IN NUMBER,
                                    p_coc_id             IN NUMBER, --added as per CR#54
                                    p_inv_item_id        IN NUMBER,
                                    p_header_id          IN NUMBER,
                                    p_line_id            IN NUMBER,
                                    p_line_location_id   IN NUMBER,
                                    p_Quantity           IN NUMBER,
                                    p_shipment_num       IN VARCHAR2,
                                    p_ledgerid           IN NUMBER,
                                    p_datecreated        IN DATE,
                                    p_currency_code      IN VARCHAR2,
                                    p_shipmentlineid     IN NUMBER,
                                    p_ponum              IN NUMBER,
                                    p_itemnum            IN VARCHAR2,
                                    P_unitprice          IN NUMBER,
                                    p_firstsale          IN NUMBER, --Added per CCR0006936
                                    p_region             IN VARCHAR --Added per CCR0007979
                                                                   )
    IS
        l_duty_amt           NUMBER;
        l_freight_amt        NUMBER;
        l_intransit_amt      NUMBER;
        l_factorycost_amt    NUMBER;
        l_overheads_amt      NUMBER;
        l_oh_nonduty_amt     NUMBER;
        l_ohduty_amt         NUMBER;
        l_freightdu_amt      NUMBER;
        l_duty_ccid          NUMBER;
        l_intransit_ccid     NUMBER;
        l_overheads_ccid     NUMBER;
        l_factorycost_ccid   NUMBER;
        l_freightdu_ccid     NUMBER;
        l_ohduty_ccid        NUMBER;
        l_oh_nonduty_ccid    NUMBER;
        l_freight_ccid       NUMBER;
        l_amt_to_credit      NUMBER;
        v_count              NUMBER;
        -- g_batch_name         VARCHAR2 (100);
        v_segment1           NUMBER := 0;
        v_segment2           NUMBER := 0;
        v_segment3           NUMBER := 0;
        v_segment4           NUMBER := 0;
        v_segment5           NUMBER := 0;
        v_segment6           NUMBER := 0;
        v_segment7           NUMBER := 0;
        v_segment8           NUMBER := 0;
        l_asn_count          NUMBER := 0;
        --START Added as per CCR0007955
        lv_segment1          VARCHAR2 (25) := NULL;
        lv_segment2          VARCHAR2 (25) := NULL;
        lv_segment3          VARCHAR2 (25) := NULL;
        lv_segment4          VARCHAR2 (25) := NULL;
        lv_segment5          VARCHAR2 (25) := NULL;
        lv_segment6          VARCHAR2 (25) := NULL;
        lv_segment7          VARCHAR2 (25) := NULL;
        lv_segment8          VARCHAR2 (25) := NULL;
        ln_null_ccid         NUMBER := 0;
        lv_region            VARCHAR2 (10);             --Added per CCR0007979
        ln_ou_id             NUMBER;                    --Added per CCR0009441
    --END Added as per CCR0007955
    BEGIN
        fnd_file.put_line (fnd_file.LOG, ' Starting of insert_into_inteface');

        -- Based on Org_id, get the DFF value associated with Overhead Element -- Added as per CCR0009441

        -- Start of Change for CCR0009441

        ln_ou_id          := NULL;

        BEGIN
            SELECT operating_unit
              INTO ln_ou_id
              FROM org_organization_definitions
             WHERE 1 = 1 AND organization_id = p_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_ou_id   := NULL;
        END;


        l_duty_amt        :=
            get_amount (p_cost                  => 'DUTY',
                        p_organization_id       => p_org_id,
                        p_inventory_item_id     => p_inv_item_id,
                        p_po_header_id          => p_header_id,
                        p_po_line_id            => p_line_id,
                        p_po_line_location_id   => p_line_location_id);

        l_duty_ccid       :=
            get_ccid (p_segments => 'DUTY', p_coc_id => p_coc_id, p_organization_id => p_org_id
                      , p_inventory_item_num => p_inv_item_id);

        -- l_amt_to_credit := p_Quantity * l_duty_amt;--commented as per CR#54

        l_amt_to_credit   := ROUND (p_Quantity * l_duty_amt, 2); --added as per CR#54

        lv_region         := ' ' || p_region;                    -- CCR0007979

        IF l_duty_ccid IS NULL OR l_duty_ccid = 0                 -- ZERO_CCID
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'failed to obtain In-transit gl account FOR SHIPMENT -'
                || p_shipment_num);

            --START Added as per CCR0007955
            IF l_duty_amt IS NOT NULL
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Duty_CCID is NULL or 0, Inserting CCID-Segments into GL Interface for Error Correction -'
                    || p_shipment_num);

                get_ccid_segments (p_segments => 'DUTY', p_coc_id => p_coc_id, p_organization_id => p_org_id, p_inventory_item_num => p_inv_item_id, p_segment1 => lv_segment1, p_segment2 => lv_segment2, p_segment3 => lv_segment3, p_segment4 => lv_segment4, p_segment5 => lv_segment5, p_segment6 => lv_segment6, p_segment7 => lv_segment7, p_segment8 => lv_segment8
                                   , p_ccid => ln_null_ccid);

                insert_gl_iface_noccid (
                    p_ledger_id       => p_ledgerid,
                    p_date_created    => p_datecreated,
                    p_currency_code   => p_currency_code, --added as per CR#54
                    --p_code_combination_id   => ln_null_ccid,
                    p_segment1        => lv_segment1,
                    p_segment2        => lv_segment2,
                    p_segment3        => lv_segment3,
                    p_segment4        => lv_segment4,
                    p_segment5        => lv_segment5,
                    p_segment6        => lv_segment6,
                    p_segment7        => lv_segment7,
                    p_segment8        => lv_segment8,
                    p_debit_amount    => NULL,
                    p_credit_amount   => l_amt_to_credit,
                    p_batch_name      => g_batch_name,
                    p_batch_desc      => g_batch_name,
                    p_journal_name    =>
                        p_shipment_num || '-' || p_shipmentlineid,
                    p_journal_desc    => g_batch_name || '-' || p_shipment_num,
                    p_line_desc       =>
                           'DUTY'
                        || '-'
                        || p_shipment_num
                        || ' '
                        || p_shipmentlineid,
                    p_context         => g_intransit_context || lv_region, --CCR0007979
                    p_attribute1      => p_shipmentlineid);



                fnd_file.put_line (
                    fnd_file.LOG,
                       ' NULL-CCID Segments > DUTY'
                    || ' \Shipment_lineid > '
                    || p_shipmentlineid
                    || ' \CCID > '
                    || ln_null_ccid
                    || ' \Segments :'
                    || lv_segment1
                    || '.'
                    || lv_segment2
                    || '.'
                    || lv_segment3
                    || '.'
                    || lv_segment4
                    || '.'
                    || lv_segment5
                    || '.'
                    || lv_segment6
                    || '.'
                    || lv_segment7
                    || '.'
                    || lv_segment8);
            END IF;
        --END Added as per CCR0007955
        ELSE
            IF l_duty_amt IS NULL
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'accrual amount is 0.  skipping GL interface insert  FOR SHIPMENT -'
                    || p_shipment_num);
            ELSE
                insert_into_gl_iface (p_ledger_id => p_ledgerid, p_date_created => p_datecreated, --p_currency_code         => 'USD',--commented as per CR#54
                                                                                                  p_currency_code => p_currency_code, --added as per CR#54
                                                                                                                                      p_code_combination_id => l_duty_ccid, p_debit_amount => NULL, p_credit_amount => l_amt_to_credit, p_batch_name => g_batch_name, p_batch_desc => g_batch_name, p_journal_name => p_shipment_num || '-' || p_shipmentlineid, p_journal_desc => g_batch_name || '-' || p_shipment_num, p_line_desc => 'DUTY' || '-' || p_shipment_num || ' ' || p_shipmentlineid, p_context => g_intransit_context || lv_region
                                      ,                          -- CCR0007979
                                        P_attribute1 => p_shipmentlineid);

                SELECT segment1, segment2, segment3,
                       segment4, segment5, segment6,
                       segment7, segment8
                  INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                 v_segment5, v_segment6, v_segment7,
                                 v_segment8
                  FROM gl_code_combinations
                 WHERE code_combination_id = l_duty_ccid;

                fnd_file.put_line (
                    fnd_file.output,
                       RPAD (p_region, 10, ' ')
                    || RPAD (p_ponum, 12, ' ')
                    || RPAD (p_shipment_num, 25, ' ')
                    || RPAD (p_itemnum, 20, ' ')
                    || RPAD (P_unitprice, 17, ' ')
                    || RPAD (P_firstsale, 17, ' ')     --Added per  CCR0006936
                    || RPAD (l_amt_to_credit, 10, ' ')
                    || RPAD (g_batch_name, 47, ' ')
                    || RPAD (p_shipment_num || '-' || p_shipmentlineid,
                             40,
                             ' ')
                    || RPAD (
                              'DUTY'
                           || '-'
                           || p_shipment_num
                           || ' '
                           || p_shipmentlineid,
                           50,
                           ' ')
                    || RPAD (
                              v_segment1
                           || '.'
                           || v_segment2
                           || '.'
                           || v_segment3
                           || '.'
                           || v_segment4
                           || '.'
                           || v_segment5
                           || '.'
                           || v_segment6
                           || '.'
                           || v_segment7
                           || '.'
                           || v_segment8,
                           60,
                           ' ')
                    || CHR (13)
                    || CHR (10));
            END IF;
        END IF;

        l_freight_amt     :=
            get_amount (p_cost                  => 'FREIGHT',
                        p_organization_id       => p_org_id,
                        p_inventory_item_id     => p_inv_item_id,
                        p_po_header_id          => p_header_id,
                        p_po_line_id            => p_line_id,
                        p_po_line_location_id   => p_line_location_id);

        l_freight_ccid    :=
            get_ccid (p_segments => 'FREIGHT', p_coc_id => p_coc_id, p_organization_id => p_org_id
                      , p_inventory_item_num => p_inv_item_id);
        --l_amt_to_credit := p_Quantity * l_freight_amt;--commented as per CR#54
        l_amt_to_credit   := ROUND (p_Quantity * l_freight_amt, 2); --added as per CR#54

        IF l_freight_ccid IS NULL OR l_freight_ccid = 0           -- ZERO_CCID
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'failed to obtain In-transit gl account FOR SHIPMENT -'
                || p_shipment_num);

            --START Added as per CCR0007955
            IF l_freight_amt IS NOT NULL
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Freight_CCID is NULL or 0, Inserting CCID-Segments into GL Interface for Error Correction -'
                    || p_shipment_num);

                get_ccid_segments (p_segments => 'FREIGHT', p_coc_id => p_coc_id, p_organization_id => p_org_id, p_inventory_item_num => p_inv_item_id, p_segment1 => lv_segment1, p_segment2 => lv_segment2, p_segment3 => lv_segment3, p_segment4 => lv_segment4, p_segment5 => lv_segment5, p_segment6 => lv_segment6, p_segment7 => lv_segment7, p_segment8 => lv_segment8
                                   , p_ccid => ln_null_ccid);

                insert_gl_iface_noccid (
                    p_ledger_id       => p_ledgerid,
                    p_date_created    => p_datecreated,
                    p_currency_code   => p_currency_code, --added as per CR#54
                    --p_code_combination_id   => ln_null_ccid,
                    p_segment1        => lv_segment1,
                    p_segment2        => lv_segment2,
                    p_segment3        => lv_segment3,
                    p_segment4        => lv_segment4,
                    p_segment5        => lv_segment5,
                    p_segment6        => lv_segment6,
                    p_segment7        => lv_segment7,
                    p_segment8        => lv_segment8,
                    p_debit_amount    => NULL,
                    p_credit_amount   => l_amt_to_credit,
                    p_batch_name      => g_batch_name,
                    p_batch_desc      => g_batch_name,
                    p_journal_name    =>
                        p_shipment_num || '-' || p_shipmentlineid,
                    p_journal_desc    => g_batch_name || '-' || p_shipment_num,
                    p_line_desc       =>
                           'FRGT'
                        || '-'
                        || p_shipment_num
                        || ' '
                        || p_shipmentlineid,
                    p_context         => g_intransit_context || lv_region, --CCR0007979
                    p_attribute1      => p_shipmentlineid);

                fnd_file.put_line (
                    fnd_file.LOG,
                       ' NULL-CCID Segments > FRGT'
                    || ' \Shipment_lineid > '
                    || p_shipmentlineid
                    || ' \CCID > '
                    || ln_null_ccid
                    || ' \Segments :'
                    || lv_segment1
                    || '.'
                    || lv_segment2
                    || '.'
                    || lv_segment3
                    || '.'
                    || lv_segment4
                    || '.'
                    || lv_segment5
                    || '.'
                    || lv_segment6
                    || '.'
                    || lv_segment7
                    || '.'
                    || lv_segment8);
            END IF;
        --END Added as per CCR0007955
        ELSE
            IF l_freight_amt IS NULL
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'accrual amount is 0.  skipping GL interface insert FOR SHIPMENT -'
                    || p_shipment_num);
            ELSE
                insert_into_gl_iface (p_ledger_id => p_ledgerid, p_date_created => p_datecreated, --p_currency_code         => 'USD',--commented as per CR#54
                                                                                                  p_currency_code => p_currency_code, --added as per CR#54
                                                                                                                                      p_code_combination_id => l_freight_ccid, p_debit_amount => NULL, p_credit_amount => l_amt_to_credit, p_batch_name => g_batch_name, p_batch_desc => g_batch_name, p_journal_name => p_shipment_num || '-' || p_shipmentlineid, p_journal_desc => g_batch_name || '-' || p_shipment_num, p_line_desc => 'FRGT' || '-' || p_shipment_num || ' ' || p_shipmentlineid, p_context => g_intransit_context || lv_region
                                      ,                           --CCR0007979
                                        P_attribute1 => p_shipmentlineid);

                SELECT segment1, segment2, segment3,
                       segment4, segment5, segment6,
                       segment7, segment8
                  INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                 v_segment5, v_segment6, v_segment7,
                                 v_segment8
                  FROM gl_code_combinations
                 WHERE code_combination_id = l_freight_ccid;

                fnd_file.put_line (
                    fnd_file.output,
                       RPAD (p_region, 10, ' ')                   --CCR0007979
                    || RPAD (p_ponum, 12, ' ')
                    || RPAD (p_shipment_num, 25, ' ')
                    || RPAD (p_itemnum, 20, ' ')
                    || RPAD (P_unitprice, 17, ' ')
                    || RPAD (l_amt_to_credit, 10, ' ')
                    || RPAD (g_batch_name, 47, ' ')
                    || RPAD (p_shipment_num || '-' || p_shipmentlineid,
                             40,
                             ' ')
                    || RPAD (
                              'FRGT'
                           || '-'
                           || p_shipment_num
                           || ' '
                           || p_shipmentlineid,
                           50,
                           ' ')
                    || RPAD (
                              v_segment1
                           || '.'
                           || v_segment2
                           || '.'
                           || v_segment3
                           || '.'
                           || v_segment4
                           || '.'
                           || v_segment5
                           || '.'
                           || v_segment6
                           || '.'
                           || v_segment7
                           || '.'
                           || v_segment8,
                           60,
                           ' ')
                    || CHR (13)
                    || CHR (10));
            END IF;
        END IF;


        l_freightdu_amt   :=
            get_amount (p_cost                  => 'FREIGHT DU',
                        p_organization_id       => p_org_id,
                        p_inventory_item_id     => p_inv_item_id,
                        p_po_header_id          => p_header_id,
                        p_po_line_id            => p_line_id,
                        p_po_line_location_id   => p_line_location_id);

        l_freightdu_ccid   :=
            get_ccid (p_segments => 'FREIGHT DU', p_coc_id => p_coc_id, p_organization_id => p_org_id
                      , p_inventory_item_num => p_inv_item_id);


        --l_amt_to_credit := p_Quantity * l_freightdu_amt;--commented as per CR#54
        l_amt_to_credit   := ROUND (p_Quantity * l_freightdu_amt, 2); --added as per CR#54

        IF l_freightdu_ccid IS NULL OR l_freightdu_ccid = 0       -- ZERO_CCID
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'failed to obtain In-transit gl account FOR SHIPMENT -'
                || p_shipment_num);

            --START Added as per CCR0007955
            IF l_freightdu_amt IS NOT NULL
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'FREIGHT DU,_CCID is NULL or 0, Inserting CCID-Segments into GL Interface for Error Correction -'
                    || p_shipment_num);

                get_ccid_segments (p_segments => 'FREIGHT DU', p_coc_id => p_coc_id, p_organization_id => p_org_id, p_inventory_item_num => p_inv_item_id, p_segment1 => lv_segment1, p_segment2 => lv_segment2, p_segment3 => lv_segment3, p_segment4 => lv_segment4, p_segment5 => lv_segment5, p_segment6 => lv_segment6, p_segment7 => lv_segment7, p_segment8 => lv_segment8
                                   , p_ccid => ln_null_ccid);

                insert_gl_iface_noccid (
                    p_ledger_id       => p_ledgerid,
                    p_date_created    => p_datecreated,
                    p_currency_code   => p_currency_code, --added as per CR#54
                    --p_code_combination_id   => ln_null_ccid,
                    p_segment1        => lv_segment1,
                    p_segment2        => lv_segment2,
                    p_segment3        => lv_segment3,
                    p_segment4        => lv_segment4,
                    p_segment5        => lv_segment5,
                    p_segment6        => lv_segment6,
                    p_segment7        => lv_segment7,
                    p_segment8        => lv_segment8,
                    p_debit_amount    => NULL,
                    p_credit_amount   => l_amt_to_credit,
                    p_batch_name      => g_batch_name,
                    p_batch_desc      => g_batch_name,
                    p_journal_name    =>
                        p_shipment_num || '-' || p_shipmentlineid,
                    p_journal_desc    => g_batch_name || '-' || p_shipment_num,
                    p_line_desc       =>
                           'FREIGHT_DU'
                        || '-'
                        || p_shipment_num
                        || ' '
                        || p_shipmentlineid,
                    p_context         => g_intransit_context || lv_region, --CCR0007979
                    p_attribute1      => p_shipmentlineid);

                fnd_file.put_line (
                    fnd_file.LOG,
                       ' NULL-CCID Segments > FREIGHT_DU'
                    || ' \Shipment_lineid > '
                    || p_shipmentlineid
                    || ' \CCID > '
                    || ln_null_ccid
                    || ' \Segments :'
                    || lv_segment1
                    || '.'
                    || lv_segment2
                    || '.'
                    || lv_segment3
                    || '.'
                    || lv_segment4
                    || '.'
                    || lv_segment5
                    || '.'
                    || lv_segment6
                    || '.'
                    || lv_segment7
                    || '.'
                    || lv_segment8);
            END IF;
        --END Added as per CCR0007955
        ELSE
            IF l_freightdu_amt IS NULL
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'accrual amount is 0.  skipping GL interface insert FOR SHIPMENT -'
                    || p_shipment_num);
            ELSE
                insert_into_gl_iface (p_ledger_id => p_ledgerid, p_date_created => p_datecreated, --p_currency_code         => 'USD',--commented as per CR#54
                                                                                                  p_currency_code => p_currency_code, --added as per CR#54
                                                                                                                                      p_code_combination_id => l_freightdu_ccid, p_debit_amount => NULL, p_credit_amount => l_amt_to_credit, p_batch_name => g_batch_name, p_batch_desc => g_batch_name, p_journal_name => p_shipment_num || '-' || p_shipmentlineid, p_journal_desc => g_batch_name || '-' || p_shipment_num, p_line_desc => 'FREIGHT_DU' || '-' || p_shipment_num || ' ' || p_shipmentlineid, p_context => g_intransit_context || lv_region
                                      ,                           --CCR0007979
                                        P_attribute1 => p_shipmentlineid);

                SELECT segment1, segment2, segment3,
                       segment4, segment5, segment6,
                       segment7, segment8
                  INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                 v_segment5, v_segment6, v_segment7,
                                 v_segment8
                  FROM gl_code_combinations
                 WHERE code_combination_id = l_freightdu_ccid;


                fnd_file.put_line (
                    fnd_file.output,
                       RPAD (p_region, 10, ' ')                   --CCR0007979
                    || RPAD (p_ponum, 12, ' ')
                    || RPAD (p_shipment_num, 25, ' ')
                    || RPAD (p_itemnum, 20, ' ')
                    || RPAD (P_unitprice, 17, ' ')
                    || RPAD (P_firstsale, 17, ' ')     --Added per  CCR0006936
                    || RPAD (l_amt_to_credit, 10, ' ')
                    || RPAD (g_batch_name, 47, ' ')
                    || RPAD (p_shipment_num || '-' || p_shipmentlineid,
                             40,
                             ' ')
                    || RPAD (
                              'FREIGHT_DU'
                           || '-'
                           || p_shipment_num
                           || ' '
                           || p_shipmentlineid,
                           50,
                           ' ')
                    || RPAD (
                              v_segment1
                           || '.'
                           || v_segment2
                           || '.'
                           || v_segment3
                           || '.'
                           || v_segment4
                           || '.'
                           || v_segment5
                           || '.'
                           || v_segment6
                           || '.'
                           || v_segment7
                           || '.'
                           || v_segment8,
                           60,
                           ' ')
                    || CHR (13)
                    || CHR (10));
            END IF;
        END IF;


        l_ohduty_amt      :=
            get_amount (p_cost                  => 'OH DUTY',
                        p_organization_id       => p_org_id,
                        p_inventory_item_id     => p_inv_item_id,
                        p_po_header_id          => p_header_id,
                        p_po_line_id            => p_line_id,
                        p_po_line_location_id   => p_line_location_id);

        l_ohduty_ccid     :=
            get_ccid (p_segments => 'OH DUTY', p_coc_id => p_coc_id, p_organization_id => p_org_id
                      , p_inventory_item_num => p_inv_item_id);

        --l_amt_to_credit := p_Quantity * l_ohduty_amt;--commented as per CR#54
        l_amt_to_credit   := ROUND (p_Quantity * l_ohduty_amt, 2); --added as per CR#54

        IF l_ohduty_ccid IS NULL OR l_ohduty_ccid = 0             -- ZERO_CCID
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'failed to obtain In-transit gl account FOR SHIPMENT -'
                || p_shipment_num);

            --START Added as per CCR0007955
            IF l_ohduty_amt IS NOT NULL
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'OH DUTY_CCID is NULL or 0, Inserting CCID-Segments into GL Interface for Error Correction -'
                    || p_shipment_num);

                get_ccid_segments (p_segments => 'OH DUTY', p_coc_id => p_coc_id, p_organization_id => p_org_id, p_inventory_item_num => p_inv_item_id, p_segment1 => lv_segment1, p_segment2 => lv_segment2, p_segment3 => lv_segment3, p_segment4 => lv_segment4, p_segment5 => lv_segment5, p_segment6 => lv_segment6, p_segment7 => lv_segment7, p_segment8 => lv_segment8
                                   , p_ccid => ln_null_ccid);

                insert_gl_iface_noccid (
                    p_ledger_id       => p_ledgerid,
                    p_date_created    => p_datecreated,
                    p_currency_code   => p_currency_code, --added as per CR#54
                    --p_code_combination_id   => ln_null_ccid,
                    p_segment1        => lv_segment1,
                    p_segment2        => lv_segment2,
                    p_segment3        => lv_segment3,
                    p_segment4        => lv_segment4,
                    p_segment5        => lv_segment5,
                    p_segment6        => lv_segment6,
                    p_segment7        => lv_segment7,
                    p_segment8        => lv_segment8,
                    p_debit_amount    => NULL,
                    p_credit_amount   => l_amt_to_credit,
                    p_batch_name      => g_batch_name,
                    p_batch_desc      => g_batch_name,
                    p_journal_name    =>
                        p_shipment_num || '-' || p_shipmentlineid,
                    p_journal_desc    => g_batch_name || '-' || p_shipment_num,
                    p_line_desc       =>
                           'OH DUTY'
                        || '-'
                        || p_shipment_num
                        || ' '
                        || p_shipmentlineid,
                    p_context         => g_intransit_context || lv_region, --CCR0007979
                    p_attribute1      => p_shipmentlineid);

                fnd_file.put_line (
                    fnd_file.LOG,
                       ' NULL-CCID Segments > OH DUTY'
                    || ' \Shipment_lineid > '
                    || p_shipmentlineid
                    || ' \CCID > '
                    || ln_null_ccid
                    || ' \Segments :'
                    || lv_segment1
                    || '.'
                    || lv_segment2
                    || '.'
                    || lv_segment3
                    || '.'
                    || lv_segment4
                    || '.'
                    || lv_segment5
                    || '.'
                    || lv_segment6
                    || '.'
                    || lv_segment7
                    || '.'
                    || lv_segment8);
            END IF;
        --END Added as per CCR0007955
        ELSE
            IF l_ohduty_amt IS NULL
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'accrual amount is 0.  skipping GL interface insert FOR SHIPMENT -'
                    || p_shipment_num);
            ELSE
                insert_into_gl_iface (p_ledger_id => p_ledgerid, p_date_created => p_datecreated, --p_currency_code         => 'USD',--commented as per CR#54
                                                                                                  p_currency_code => p_currency_code, --added as per CR#54
                                                                                                                                      p_code_combination_id => l_ohduty_ccid, p_debit_amount => NULL, p_credit_amount => l_amt_to_credit, p_batch_name => g_batch_name, p_batch_desc => g_batch_name, p_journal_name => p_shipment_num || '-' || p_shipmentlineid, p_journal_desc => g_batch_name || '-' || p_shipment_num, p_line_desc => 'OH DUTY' || '-' || p_shipment_num || ' ' || p_shipmentlineid, p_context => g_intransit_context || lv_region
                                      ,                           --CCR0007979
                                        P_attribute1 => p_shipmentlineid);


                SELECT segment1, segment2, segment3,
                       segment4, segment5, segment6,
                       segment7, segment8
                  INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                 v_segment5, v_segment6, v_segment7,
                                 v_segment8
                  FROM gl_code_combinations
                 WHERE code_combination_id = l_ohduty_ccid;


                fnd_file.put_line (
                    fnd_file.output,
                       RPAD (p_region, 10, ' ')                   --CCR0007979
                    || RPAD (p_ponum, 12, ' ')
                    || RPAD (p_shipment_num, 25, ' ')
                    || RPAD (p_itemnum, 20, ' ')
                    || RPAD (P_unitprice, 17, ' ')
                    || RPAD (P_firstsale, 17, ' ')     --Added per  CCR0006936
                    || RPAD (l_amt_to_credit, 10, ' ')
                    || RPAD (g_batch_name, 47, ' ')
                    || RPAD (p_shipment_num || '-' || p_shipmentlineid,
                             40,
                             ' ')
                    || RPAD (
                              'OH DUTY'
                           || '-'
                           || p_shipment_num
                           || ' '
                           || p_shipmentlineid,
                           50,
                           ' ')
                    || RPAD (
                              v_segment1
                           || '.'
                           || v_segment2
                           || '.'
                           || v_segment3
                           || '.'
                           || v_segment4
                           || '.'
                           || v_segment5
                           || '.'
                           || v_segment6
                           || '.'
                           || v_segment7
                           || '.'
                           || v_segment8,
                           60,
                           ' ')
                    || CHR (13)
                    || CHR (10));
            END IF;
        END IF;


        l_oh_nonduty_amt   :=
            get_amount (p_cost                  => 'OH NONDUTY',
                        p_organization_id       => p_org_id,
                        p_inventory_item_id     => p_inv_item_id,
                        p_po_header_id          => p_header_id,
                        p_po_line_id            => p_line_id,
                        p_po_line_location_id   => p_line_location_id);

        l_oh_nonduty_ccid   :=
            get_ccid (p_segments => 'OH NONDUTY', p_coc_id => p_coc_id, p_organization_id => p_org_id
                      , p_inventory_item_num => p_inv_item_id);

        -- l_amt_to_credit := p_Quantity * l_oh_nonduty_amt;--commented as per CR#54
        l_amt_to_credit   := ROUND (p_Quantity * l_oh_nonduty_amt, 2); --added as per CR#54

        IF l_oh_nonduty_ccid IS NULL OR l_oh_nonduty_ccid = 0     -- ZERO_CCID
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'failed to obtain In-transit gl account FOR SHIPMENT -'
                || p_shipment_num);

            --START Added as per CCR0007955
            IF l_oh_nonduty_amt IS NOT NULL
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'OH NONDUTY_CCID is NULL or 0, Inserting CCID-Segments into GL Interface for Error Correction -'
                    || p_shipment_num);

                get_ccid_segments (p_segments => 'OH NONDUTY', p_coc_id => p_coc_id, p_organization_id => p_org_id, p_inventory_item_num => p_inv_item_id, p_segment1 => lv_segment1, p_segment2 => lv_segment2, p_segment3 => lv_segment3, p_segment4 => lv_segment4, p_segment5 => lv_segment5, p_segment6 => lv_segment6, p_segment7 => lv_segment7, p_segment8 => lv_segment8
                                   , p_ccid => ln_null_ccid);

                insert_gl_iface_noccid (
                    p_ledger_id       => p_ledgerid,
                    p_date_created    => p_datecreated,
                    p_currency_code   => p_currency_code, --added as per CR#54
                    --p_code_combination_id   => ln_null_ccid,
                    p_segment1        => lv_segment1,
                    p_segment2        => lv_segment2,
                    p_segment3        => lv_segment3,
                    p_segment4        => lv_segment4,
                    p_segment5        => lv_segment5,
                    p_segment6        => lv_segment6,
                    p_segment7        => lv_segment7,
                    p_segment8        => lv_segment8,
                    p_debit_amount    => NULL,
                    p_credit_amount   => l_amt_to_credit,
                    p_batch_name      => g_batch_name,
                    p_batch_desc      => g_batch_name,
                    p_journal_name    =>
                        p_shipment_num || '-' || p_shipmentlineid,
                    p_journal_desc    => g_batch_name || '-' || p_shipment_num,
                    p_line_desc       =>
                           'OH NONDUTY'
                        || '-'
                        || p_shipment_num
                        || ' '
                        || p_shipmentlineid,
                    p_context         => g_intransit_context || lv_region, --CCR0007979
                    p_attribute1      => p_shipmentlineid);

                fnd_file.put_line (
                    fnd_file.LOG,
                       ' NULL-CCID Segments > OH NONDUTY'
                    || ' \Shipment_lineid > '
                    || p_shipmentlineid
                    || ' \CCID > '
                    || ln_null_ccid
                    || ' \Segments :'
                    || lv_segment1
                    || '.'
                    || lv_segment2
                    || '.'
                    || lv_segment3
                    || '.'
                    || lv_segment4
                    || '.'
                    || lv_segment5
                    || '.'
                    || lv_segment6
                    || '.'
                    || lv_segment7
                    || '.'
                    || lv_segment8);
            END IF;
        --END Added as per CCR0007955
        ELSE
            IF l_oh_nonduty_amt IS NULL
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'accrual amount is 0.  skipping GL interface insert  FOR SHIPMENT -'
                    || p_shipment_num);
            ELSE
                insert_into_gl_iface (p_ledger_id => p_ledgerid, p_date_created => p_datecreated, --p_currency_code         => 'USD',--commented as per CR#54
                                                                                                  p_currency_code => p_currency_code, --added as per CR#54
                                                                                                                                      p_code_combination_id => l_oh_nonduty_ccid, p_debit_amount => NULL, p_credit_amount => l_amt_to_credit, p_batch_name => g_batch_name, p_batch_desc => g_batch_name, p_journal_name => p_shipment_num || '-' || p_shipmentlineid, p_journal_desc => g_batch_name || '-' || p_shipment_num, p_line_desc => 'OH NONDUTY' || '-' || p_shipment_num || ' ' || p_shipmentlineid, p_context => g_intransit_context || lv_region
                                      ,                           --CCR0007979
                                        P_attribute1 => p_shipmentlineid);

                SELECT segment1, segment2, segment3,
                       segment4, segment5, segment6,
                       segment7, segment8
                  INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                 v_segment5, v_segment6, v_segment7,
                                 v_segment8
                  FROM gl_code_combinations
                 WHERE code_combination_id = l_oh_nonduty_ccid;

                fnd_file.put_line (
                    fnd_file.output,
                       RPAD (p_region, 10, ' ')                   --CCR0007979
                    || RPAD (p_ponum, 12, ' ')
                    || RPAD (p_shipment_num, 25, ' ')
                    || RPAD (p_itemnum, 20, ' ')
                    || RPAD (P_unitprice, 17, ' ')
                    || RPAD (P_firstsale, 17, ' ')     --Added per  CCR0006936
                    || RPAD (l_amt_to_credit, 10, ' ')
                    || RPAD (g_batch_name, 47, ' ')
                    || RPAD (p_shipment_num || '-' || p_shipmentlineid,
                             40,
                             ' ')
                    || RPAD (
                              'OH NONDUTY'
                           || '-'
                           || p_shipment_num
                           || ' '
                           || p_shipmentlineid,
                           50,
                           ' ')
                    || RPAD (
                              v_segment1
                           || '.'
                           || v_segment2
                           || '.'
                           || v_segment3
                           || '.'
                           || v_segment4
                           || '.'
                           || v_segment5
                           || '.'
                           || v_segment6
                           || '.'
                           || v_segment7
                           || '.'
                           || v_segment8,
                           60,
                           ' ')
                    || CHR (13)
                    || CHR (10));
            END IF;
        END IF;

        l_overheads_amt   :=
            get_amount (p_cost                  => 'OVERHEADS ',
                        p_organization_id       => p_org_id,
                        p_inventory_item_id     => p_inv_item_id,
                        p_po_header_id          => p_header_id,
                        p_po_line_id            => p_line_id,
                        p_po_line_location_id   => p_line_location_id);

        l_overheads_ccid   :=
            get_ccid (p_segments => 'OVERHEADS ', p_coc_id => p_coc_id, p_organization_id => p_org_id
                      , p_inventory_item_num => p_inv_item_id);

        -- l_amt_to_credit := p_Quantity * l_overheads_amt;--commented as per CR#54
        l_amt_to_credit   := ROUND (p_Quantity * l_overheads_amt, 2); --added as per CR#54

        --   IF lv_final_flag = 'Y'
        --   THEN

        IF l_overheads_ccid IS NULL OR l_overheads_ccid = 0       -- ZERO_CCID
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'failed to obtain In-transit gl account FOR SHIPMENT -'
                || p_shipment_num);

            --START Added as per CCR0007955
            IF l_overheads_amt IS NOT NULL
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'OVERHEADS_CCID is NULL or 0, Inserting CCID-Segments into GL Interface for Error Correction -'
                    || p_shipment_num);

                get_ccid_segments (p_segments => 'OVERHEADS ', p_coc_id => p_coc_id, p_organization_id => p_org_id, p_inventory_item_num => p_inv_item_id, p_segment1 => lv_segment1, p_segment2 => lv_segment2, p_segment3 => lv_segment3, p_segment4 => lv_segment4, p_segment5 => lv_segment5, p_segment6 => lv_segment6, p_segment7 => lv_segment7, p_segment8 => lv_segment8
                                   , p_ccid => ln_null_ccid);

                insert_gl_iface_noccid (
                    p_ledger_id       => p_ledgerid,
                    p_date_created    => p_datecreated,
                    p_currency_code   => p_currency_code, --added as per CR#54
                    --p_code_combination_id   => ln_null_ccid,
                    p_segment1        => lv_segment1,
                    p_segment2        => lv_segment2,
                    p_segment3        => lv_segment3,
                    p_segment4        => lv_segment4,
                    p_segment5        => lv_segment5,
                    p_segment6        => lv_segment6,
                    p_segment7        => lv_segment7,
                    p_segment8        => lv_segment8,
                    p_debit_amount    => l_amt_to_credit,
                    p_credit_amount   => NULL,
                    p_batch_name      => g_batch_name,
                    p_batch_desc      => g_batch_name,
                    p_journal_name    =>
                        p_shipment_num || '-' || p_shipmentlineid,
                    p_journal_desc    => g_batch_name || '-' || p_shipment_num,
                    p_line_desc       =>
                           'OVERHEADS '
                        || '-'
                        || p_shipment_num
                        || ' '
                        || p_shipmentlineid,
                    p_context         => g_intransit_context || lv_region, --CCR0007979
                    p_attribute1      => p_shipmentlineid);


                fnd_file.put_line (
                    fnd_file.LOG,
                       ' NULL-CCID Segments > OVERHEADS'
                    || ' \Shipment_lineid > '
                    || p_shipmentlineid
                    || ' \CCID > '
                    || ln_null_ccid
                    || ' \Segments :'
                    || lv_segment1
                    || '.'
                    || lv_segment2
                    || '.'
                    || lv_segment3
                    || '.'
                    || lv_segment4
                    || '.'
                    || lv_segment5
                    || '.'
                    || lv_segment6
                    || '.'
                    || lv_segment7
                    || '.'
                    || lv_segment8);
            END IF;
        --END Added as per CCR0007955
        ELSE
            IF l_overheads_amt IS NULL
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'accrual amount is 0.  skipping GL interface insert FOR SHIPMENT -'
                    || p_shipment_num);
            ELSE
                insert_into_gl_iface (p_ledger_id => p_ledgerid, p_date_created => p_datecreated, --p_currency_code         => 'USD',--commented as per CR#54
                                                                                                  p_currency_code => p_currency_code, --added as per CR#54
                                                                                                                                      p_code_combination_id => l_overheads_ccid, p_debit_amount => l_amt_to_credit, p_credit_amount => NULL, p_batch_name => g_batch_name, p_batch_desc => g_batch_name, p_journal_name => p_shipment_num || '-' || p_shipmentlineid, p_journal_desc => g_batch_name || '-' || p_shipment_num, p_line_desc => 'OVERHEADS ' || '-' || p_shipment_num || ' ' || p_shipmentlineid, p_context => g_intransit_context || lv_region
                                      ,                           --CCR0007979
                                        P_attribute1 => p_shipmentlineid);

                SELECT segment1, segment2, segment3,
                       segment4, segment5, segment6,
                       segment7, segment8
                  INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                 v_segment5, v_segment6, v_segment7,
                                 v_segment8
                  FROM gl_code_combinations
                 WHERE code_combination_id = l_overheads_ccid;

                fnd_file.put_line (
                    fnd_file.output,
                       RPAD (p_region, 10, ' ')                   --CCR0007979
                    || RPAD (p_ponum, 12, ' ')
                    || RPAD (p_shipment_num, 25, ' ')
                    || RPAD (p_itemnum, 20, ' ')
                    || RPAD (P_unitprice, 17, ' ')
                    || RPAD (P_firstsale, 17, ' ')     --Added per  CCR0006936
                    || RPAD (l_amt_to_credit, 10, ' ')
                    || RPAD (g_batch_name, 47, ' ')
                    || RPAD (p_shipment_num || '-' || p_shipmentlineid,
                             40,
                             ' ')
                    || RPAD (
                              'OVERHEADS '
                           || '-'
                           || p_shipment_num
                           || ' '
                           || p_shipmentlineid,
                           50,
                           ' ')
                    || RPAD (
                              v_segment1
                           || '.'
                           || v_segment2
                           || '.'
                           || v_segment3
                           || '.'
                           || v_segment4
                           || '.'
                           || v_segment5
                           || '.'
                           || v_segment6
                           || '.'
                           || v_segment7
                           || '.'
                           || v_segment8,
                           60,
                           ' ')
                    || CHR (13)
                    || CHR (10));
            END IF;
        END IF;

        --   END IF; -- Added as per CCR0009441

        l_factorycost_amt   :=
            get_amount (p_cost                  => 'Factory Cost',
                        p_organization_id       => p_org_id,
                        p_inventory_item_id     => p_inv_item_id,
                        p_po_header_id          => p_header_id,
                        p_po_line_id            => p_line_id,
                        p_po_line_location_id   => p_line_location_id);

        l_factorycost_ccid   :=
            get_ccid (p_segments => 'Factory Cost', p_coc_id => p_coc_id, p_organization_id => p_org_id
                      , p_inventory_item_num => p_inv_item_id);

        -- l_amt_to_credit := p_Quantity * l_factorycost_amt;--commented as per CR#54

        l_amt_to_credit   := ROUND (p_Quantity * l_factorycost_amt, 2); --added as per CR#54

        IF l_factorycost_ccid IS NULL OR l_factorycost_ccid = 0   -- ZERO_CCID
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'failed to obtain In-transit gl account FOR SHIPMENT -'
                || p_shipment_num);

            --START Added as per CCR0007955
            IF l_factorycost_amt IS NOT NULL
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Factory Cost_CCID is NULL or 0, Inserting CCID-Segments into GL Interface for Error Correction -'
                    || p_shipment_num);

                get_ccid_segments (p_segments => 'Factory Cost', p_coc_id => p_coc_id, p_organization_id => p_org_id, p_inventory_item_num => p_inv_item_id, p_segment1 => lv_segment1, p_segment2 => lv_segment2, p_segment3 => lv_segment3, p_segment4 => lv_segment4, p_segment5 => lv_segment5, p_segment6 => lv_segment6, p_segment7 => lv_segment7, p_segment8 => lv_segment8
                                   , p_ccid => ln_null_ccid);

                insert_gl_iface_noccid (
                    p_ledger_id       => p_ledgerid,
                    p_date_created    => p_datecreated,
                    p_currency_code   => p_currency_code, --added as per CR#54
                    --p_code_combination_id   => ln_null_ccid,
                    p_segment1        => lv_segment1,
                    p_segment2        => lv_segment2,
                    p_segment3        => lv_segment3,
                    p_segment4        => lv_segment4,
                    p_segment5        => lv_segment5,
                    p_segment6        => lv_segment6,
                    p_segment7        => lv_segment7,
                    p_segment8        => lv_segment8,
                    p_debit_amount    => NULL,
                    p_credit_amount   => l_amt_to_credit,
                    p_batch_name      => g_batch_name,
                    p_batch_desc      => g_batch_name,
                    p_journal_name    =>
                        p_shipment_num || '-' || p_shipmentlineid,
                    p_journal_desc    => g_batch_name || '-' || p_shipment_num,
                    p_line_desc       =>
                           'Factory Cost'
                        || '-'
                        || p_shipment_num
                        || ' '
                        || p_shipmentlineid,
                    p_context         => g_intransit_context || lv_region, --CCR0007979
                    p_attribute1      => p_shipmentlineid);

                fnd_file.put_line (
                    fnd_file.LOG,
                       ' NULL-CCID Segments > Factory Cost'
                    || ' \Shipment_lineid > '
                    || p_shipmentlineid
                    || ' \CCID > '
                    || ln_null_ccid
                    || ' \Segments :'
                    || lv_segment1
                    || '.'
                    || lv_segment2
                    || '.'
                    || lv_segment3
                    || '.'
                    || lv_segment4
                    || '.'
                    || lv_segment5
                    || '.'
                    || lv_segment6
                    || '.'
                    || lv_segment7
                    || '.'
                    || lv_segment8);
            END IF;
        --END Added as per CCR0007955
        ELSE
            IF l_factorycost_amt IS NULL
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'accrual amount is 0.  skipping GL interface insert FOR SHIPMENT -'
                    || p_shipment_num);
            ELSE
                insert_into_gl_iface (p_ledger_id => p_ledgerid, p_date_created => p_datecreated, --p_currency_code         => 'USD',--commented as per CR#54
                                                                                                  p_currency_code => p_currency_code, --added as per CR#54
                                                                                                                                      p_code_combination_id => l_factorycost_ccid, p_debit_amount => NULL, p_credit_amount => l_amt_to_credit, p_batch_name => g_batch_name, p_batch_desc => g_batch_name, p_journal_name => p_shipment_num || '-' || p_shipmentlineid, p_journal_desc => g_batch_name || '-' || p_shipment_num, p_line_desc => 'Factory Cost' || '-' || p_shipment_num || ' ' || p_shipmentlineid, p_context => g_intransit_context || lv_region
                                      ,                           --CCR0007979
                                        P_attribute1 => p_shipmentlineid);

                SELECT segment1, segment2, segment3,
                       segment4, segment5, segment6,
                       segment7, segment8
                  INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                 v_segment5, v_segment6, v_segment7,
                                 v_segment8
                  FROM gl_code_combinations
                 WHERE code_combination_id = l_factorycost_ccid;

                fnd_file.put_line (
                    fnd_file.output,
                       RPAD (p_region, 10, ' ')                   --CCR0007979
                    || RPAD (p_ponum, 12, ' ')
                    || RPAD (p_shipment_num, 25, ' ')
                    || RPAD (p_itemnum, 20, ' ')
                    || RPAD (P_unitprice, 17, ' ')
                    || RPAD (P_firstsale, 17, ' ')     --Added per  CCR0006936
                    || RPAD (l_amt_to_credit, 10, ' ')
                    || RPAD (g_batch_name, 47, ' ')
                    || RPAD (p_shipment_num || '-' || p_shipmentlineid,
                             40,
                             ' ')
                    || RPAD (
                              'Factory Cost'
                           || '-'
                           || p_shipment_num
                           || ' '
                           || p_shipmentlineid,
                           50,
                           ' ')
                    || RPAD (
                              v_segment1
                           || '.'
                           || v_segment2
                           || '.'
                           || v_segment3
                           || '.'
                           || v_segment4
                           || '.'
                           || v_segment5
                           || '.'
                           || v_segment6
                           || '.'
                           || v_segment7
                           || '.'
                           || v_segment8,
                           60,
                           ' ')
                    || CHR (13)
                    || CHR (10));
            END IF;
        END IF;

        l_intransit_amt   :=
            get_amount (p_cost                  => 'In Transit',
                        p_organization_id       => p_org_id,
                        p_inventory_item_id     => p_inv_item_id,
                        p_po_header_id          => p_header_id,
                        p_po_line_id            => p_line_id,
                        p_po_line_location_id   => p_line_location_id);

        l_intransit_ccid   :=
            get_ccid (p_segments => 'In Transit', p_coc_id => p_coc_id, p_organization_id => p_org_id
                      , p_inventory_item_num => p_inv_item_id);

        l_amt_to_credit   := p_Quantity * l_intransit_amt; --commented as per CR#54
        l_amt_to_credit   := ROUND (p_Quantity * l_intransit_amt, 2); --added as per CR#54

        IF l_intransit_ccid IS NULL OR l_intransit_ccid = 0       -- ZERO_CCID
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'failed to obtain In-transit gl account FOR SHIPMENT -'
                || p_shipment_num);

            --START Added as per CCR0007955
            IF l_intransit_amt IS NOT NULL
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'In Transit_CCID is NULL or 0, Inserting CCID-Segments into GL Interface for Error Correction -'
                    || p_shipment_num);

                get_ccid_segments (p_segments => 'In Transit', p_coc_id => p_coc_id, p_organization_id => p_org_id, p_inventory_item_num => p_inv_item_id, p_segment1 => lv_segment1, p_segment2 => lv_segment2, p_segment3 => lv_segment3, p_segment4 => lv_segment4, p_segment5 => lv_segment5, p_segment6 => lv_segment6, p_segment7 => lv_segment7, p_segment8 => lv_segment8
                                   , p_ccid => ln_null_ccid);

                insert_gl_iface_noccid (
                    p_ledger_id       => p_ledgerid,
                    p_date_created    => p_datecreated,
                    p_currency_code   => p_currency_code, --added as per CR#54
                    --p_code_combination_id   => ln_null_ccid,
                    p_segment1        => lv_segment1,
                    p_segment2        => lv_segment2,
                    p_segment3        => lv_segment3,
                    p_segment4        => lv_segment4,
                    p_segment5        => lv_segment5,
                    p_segment6        => lv_segment6,
                    p_segment7        => lv_segment7,
                    p_segment8        => lv_segment8,
                    p_debit_amount    => l_amt_to_credit,
                    p_credit_amount   => NULL,
                    p_batch_name      => g_batch_name,
                    p_batch_desc      => g_batch_name,
                    p_journal_name    =>
                        p_shipment_num || '-' || p_shipmentlineid,
                    p_journal_desc    => g_batch_name || '-' || p_shipment_num,
                    p_line_desc       =>
                           'In Transit'
                        || '-'
                        || p_shipment_num
                        || ' '
                        || p_shipmentlineid,
                    p_context         => g_intransit_context || lv_region, --CCR0007979
                    p_attribute1      => p_shipmentlineid);

                fnd_file.put_line (
                    fnd_file.LOG,
                       ' NULL-CCID Segments > In Transit'
                    || ' \Shipment_lineid > '
                    || p_shipmentlineid
                    || ' \CCID > '
                    || ln_null_ccid
                    || ' \Segments :'
                    || lv_segment1
                    || '.'
                    || lv_segment2
                    || '.'
                    || lv_segment3
                    || '.'
                    || lv_segment4
                    || '.'
                    || lv_segment5
                    || '.'
                    || lv_segment6
                    || '.'
                    || lv_segment7
                    || '.'
                    || lv_segment8);
            END IF;
        --END Added as per CCR0007955
        ELSE
            IF l_intransit_amt IS NULL
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'accrual amount is 0.  skipping GL interface insertFOR SHIPMENT -'
                    || p_shipment_num);
            ELSE
                insert_into_gl_iface (p_ledger_id => p_ledgerid, p_date_created => p_datecreated, --p_currency_code         => 'USD',--commented as per CR#54
                                                                                                  p_currency_code => p_currency_code, --added as per CR#54
                                                                                                                                      p_code_combination_id => l_intransit_ccid, p_debit_amount => l_amt_to_credit, p_credit_amount => NULL, p_batch_name => g_batch_name, p_batch_desc => g_batch_name, p_journal_name => p_shipment_num || '-' || p_shipmentlineid, p_journal_desc => g_batch_name || '-' || p_shipment_num, p_line_desc => 'In Transit' || '-' || p_shipment_num || ' ' || p_shipmentlineid, p_context => g_intransit_context || lv_region
                                      ,                           --CCR0007979
                                        P_attribute1 => p_shipmentlineid);

                SELECT segment1, segment2, segment3,
                       segment4, segment5, segment6,
                       segment7, segment8
                  INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                 v_segment5, v_segment6, v_segment7,
                                 v_segment8
                  FROM gl_code_combinations
                 WHERE code_combination_id = l_intransit_ccid;

                fnd_file.put_line (
                    fnd_file.output,
                       RPAD (p_region, 10, ' ')                   --CCR0007979
                    || RPAD (p_ponum, 12, ' ')
                    || RPAD (p_shipment_num, 25, ' ')
                    || RPAD (p_itemnum, 20, ' ')
                    || RPAD (P_unitprice, 17, ' ')
                    || RPAD (P_firstsale, 17, ' ')     --Added per  CCR0006936
                    || RPAD (l_amt_to_credit, 10, ' ')
                    || RPAD (g_batch_name, 47, ' ')
                    || RPAD (p_shipment_num || '-' || p_shipmentlineid,
                             40,
                             ' ')
                    || RPAD (
                              'In Transit'
                           || '-'
                           || p_shipment_num
                           || ' '
                           || p_shipmentlineid,
                           50,
                           ' ')
                    || RPAD (
                              v_segment1
                           || '.'
                           || v_segment2
                           || '.'
                           || v_segment3
                           || '.'
                           || v_segment4
                           || '.'
                           || v_segment5
                           || '.'
                           || v_segment6
                           || '.'
                           || v_segment7
                           || '.'
                           || v_segment8,
                           60,
                           ' ')
                    || CHR (13)
                    || CHR (10));
            END IF;
        END IF;

        --Change as per CR#54
        SELECT COUNT (attribute1)
          INTO v_count
          FROM gl_interface
         WHERE     context = g_intransit_context || lv_region
               AND attribute1 = p_shipmentlineid;                 --CCR0007979

        IF v_count > 0
        THEN
            UPDATE APPS.RCV_SHIPMENT_LINES
               --change starts as per defect#749
               --SET ATTRIBUTE2 = 'Y'
               SET ATTRIBUTE5 = 'Y', -- ELEMENTS_IN_DFF - Start
                                     ATTRIBUTE2 = NVL (p_firstsale, p_unitprice), --Added per  CCR0006936
                                                                                  ATTRIBUTE6 = l_duty_amt,
                   ATTRIBUTE7 = l_freight_amt, ATTRIBUTE8 = l_freightdu_amt, ATTRIBUTE9 = l_ohduty_amt,
                   ATTRIBUTE10 = l_oh_nonduty_amt, ATTRIBUTE11 = l_overheads_amt
             -- ELEMENTS_IN_DFF - End
             --change ends as per defect#749
             WHERE SHIPMENT_LINE_ID = p_shipmentlineid;
        END IF;

        --Change as per CR#54
        /*l_asn_count := l_asn_count + 1;

              IF l_asn_count >= 500
              THEN
                 COMMIT;
                 l_asn_count := 0;
              END IF;*/
        --Change as per CR#54

        fnd_file.put_line (fnd_file.LOG, ' End of insert_into_inteface');
    -- EXCEPTION_HANDLE -- Start
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error occurred in insert_into_inteface : '
                || SQLERRM);
            fnd_file.put_line (fnd_file.LOG,
                               'Errored ASN # : ' || p_shipment_num);
            fnd_file.put_line (fnd_file.LOG,
                               'Errored ASN Line id : ' || p_shipmentlineid);
    -- EXCEPTION_HANDLE -- End
    END insert_into_inteface;

    /* Procedure  to Insert the Data into Interface Table */
    PROCEDURE insert_into_gl_iface (p_ledger_id IN NUMBER, p_date_created IN DATE, p_currency_code IN VARCHAR2, p_code_combination_id IN NUMBER, p_debit_amount IN NUMBER, p_credit_amount IN NUMBER, p_batch_name IN VARCHAR2, p_batch_desc IN VARCHAR2, p_journal_name IN VARCHAR2, p_journal_desc IN VARCHAR2, p_line_desc IN VARCHAR2, p_context IN VARCHAR2
                                    , p_attribute1 IN VARCHAR2)
    IS
        l_proc_name     VARCHAR2 (200)
                            := lg_package_name || '.insert_into_gl_iface';
        l_period_name   gl_periods.period_name%TYPE;
    BEGIN
        --   fnd_file.put_line( fnd_file.log, ' Starting of insert_into_gl_iface');

        SELECT period_name
          INTO l_period_name
          FROM gl_periods
         WHERE     period_set_name = 'DO_FY_CALENDAR'
               AND start_date <= TRUNC (p_date_created)
               AND end_date >= TRUNC (p_date_created);

        -- Start of Change for CCR0009984

        --   IF NVL(p_insert_into_gl,'N') = 'Y' -- Added as per  CCR0009441
        --   THEN

        -- End of Change for CCR0009441

        INSERT INTO apps.gl_interface (status, ledger_id, set_of_books_id,
                                       user_je_source_name, user_je_category_name, accounting_date, currency_code, date_created, created_by, actual_flag, period_name, code_combination_id, entered_dr, entered_cr, reference1, reference2, reference4, reference5
                                       , reference10, context, attribute1)
             VALUES ('NEW', p_ledger_id, p_ledger_id,
                     lg_je_source, lg_je_category, --  SYSDATE,--commented on 02/05/16
                                                   p_date_created, --added on 02/05/16
                     --Change as per CR#54
                     -- 'USD',
                     p_currency_code, --Change as per CR#54
                                      p_date_created, fnd_global.user_id,
                     'A', l_period_name, p_code_combination_id,
                     p_debit_amount, p_credit_amount, p_batch_name,
                     p_batch_desc, p_journal_name, p_journal_desc,
                     p_line_desc, p_context, p_attribute1);
    --   END IF; -- Added as per CCR0009984

    --   fnd_file.put_line( fnd_file.log, ' End of insert_into_gl_iface');

    -- EXCEPTION_HANDLE -- Start

    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected Error occurred in insert_into_gl_iface : '
                || SQLERRM);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Errored Journal Description / Reference5 : '
                || p_journal_desc);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Errored Journal Line Description / Reference10 : '
                || p_line_desc);
    -- EXCEPTION_HANDLE -- End
    END insert_into_gl_iface;


    --START Added as per CCR0007955
    /* Procedure to Insert without CCID into Interface Table */
    PROCEDURE insert_gl_iface_noccid (p_ledger_id       IN NUMBER,
                                      p_date_created    IN DATE,
                                      p_currency_code   IN VARCHAR2,
                                      -- p_code_combination_id   IN NUMBER,
                                      p_segment1        IN VARCHAR2,
                                      p_segment2        IN VARCHAR2,
                                      p_segment3        IN VARCHAR2,
                                      p_segment4        IN VARCHAR2,
                                      p_segment5        IN VARCHAR2,
                                      p_segment6        IN VARCHAR2,
                                      p_segment7        IN VARCHAR2,
                                      p_segment8        IN VARCHAR2,
                                      p_debit_amount    IN NUMBER,
                                      p_credit_amount   IN NUMBER,
                                      p_batch_name      IN VARCHAR2,
                                      p_batch_desc      IN VARCHAR2,
                                      p_journal_name    IN VARCHAR2,
                                      p_journal_desc    IN VARCHAR2,
                                      p_line_desc       IN VARCHAR2,
                                      p_context         IN VARCHAR2,
                                      p_attribute1      IN VARCHAR2)
    IS
        l_proc_name     VARCHAR2 (200)
                            := lg_package_name || '.insert_into_gl_iface';
        l_period_name   gl_periods.period_name%TYPE;
    BEGIN
        --   fnd_file.put_line( fnd_file.log, ' Starting of insert_into_gl_iface');

        SELECT period_name
          INTO l_period_name
          FROM gl_periods
         WHERE     period_set_name = 'DO_FY_CALENDAR'
               AND start_date <= TRUNC (p_date_created)
               AND end_date >= TRUNC (p_date_created);

        -- Start of Change for CCR0009984

        --   IF NVL(p_insert_into_gl,'N') = 'Y'    -- Added as per CCR0009441
        --   THEN

        -- End of Change for CCR0009441

        INSERT INTO apps.gl_interface (status, ledger_id, set_of_books_id,
                                       user_je_source_name, user_je_category_name, accounting_date, currency_code, date_created, created_by, actual_flag, period_name, -- code_combination_id,
                                                                                                                                                                       segment1, segment2, segment3, segment4, segment5, segment6, segment7, segment8, entered_dr, entered_cr, reference1, reference2, reference4, reference5, reference10, context
                                       , attribute1)
             VALUES ('NEW', p_ledger_id, p_ledger_id,
                     lg_je_source, lg_je_category, --  SYSDATE,--commented on 02/05/16
                                                   p_date_created, --added on 02/05/16
                     --Change as per CR#54
                     -- 'USD',
                     p_currency_code, --Change as per CR#54
                                      p_date_created, fnd_global.user_id,
                     'A', l_period_name, -- p_code_combination_id,
                                         p_segment1,
                     p_segment2, p_segment3, p_segment4,
                     p_segment5, p_segment6, p_segment7,
                     p_segment8, p_debit_amount, p_credit_amount,
                     p_batch_name, p_batch_desc, p_journal_name,
                     p_journal_desc, p_line_desc, p_context,
                     p_attribute1);
    --   END IF; -- Added as per CCR0009441
    --   fnd_file.put_line( fnd_file.log, ' End of insert_into_gl_iface');

    -- EXCEPTION_HANDLE -- Start

    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected Error occurred in insert_gl_iface_noccid : '
                || SQLERRM);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Errored Journal Description / Reference5 : '
                || p_journal_desc);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Errored Journal Line Description / Reference10 : '
                || p_line_desc);
    -- EXCEPTION_HANDLE -- End
    END insert_gl_iface_noccid;

    --END Added as per CCR0007955


    /* Produre to Create The In_Transit Journals for ASN */

    PROCEDURE Create_In_Transit (psqlstat               OUT VARCHAR2,
                                 perrproc               OUT VARCHAR2,
                                 p_ou                IN     NUMBER, --added as per CR#54
                                 p_shipment_number   IN     VARCHAR2,
                                 p_cst_adj_only      IN     VARCHAR2) --Added per  CCR0006936
    IS
        l_duty_amt                    NUMBER;
        l_freight_amt                 NUMBER;
        l_intransit_amt               NUMBER;
        l_factorycost_amt             NUMBER;
        l_overheads_amt               NUMBER;
        l_oh_nonduty_amt              NUMBER;
        l_ohduty_amt                  NUMBER;
        l_freightdu_amt               NUMBER;
        l_duty_cost                   NUMBER;
        v_count                       NUMBER;
        l_freight_cost                NUMBER;
        l_intransit_cost              NUMBER;
        l_factorycost_cost            NUMBER;
        l_overheads_cost              NUMBER;
        l_oh_nonduty_cost             NUMBER;
        l_ohduty_cost                 NUMBER;
        l_freightdu_cost              NUMBER;
        l_duty_ccid                   NUMBER;
        l_intransit_ccid              NUMBER;
        l_overheads_ccid              NUMBER;
        l_factorycost_ccid            NUMBER;
        l_freightdu_ccid              NUMBER;
        l_ohduty_ccid                 NUMBER;
        l_oh_nonduty_ccid             NUMBER;
        l_freight_ccid                NUMBER;
        l_amt_to_credit               NUMBER;
        l_amt_to_debit                NUMBER;
        l_org_id                      NUMBER;
        l_proc_name                   VARCHAR2 (200)
            := lg_package_name || '.insert_into_gl_iface';
        l_period_name                 gl_periods.period_name%TYPE;
        l_running_amount              NUMBER := 0;
        v_quantity                    NUMBER;
        shipped_quantity              NUMBER;
        received_quantity             NUMBER;
        v_segment1                    NUMBER := 0;
        v_segment2                    NUMBER := 0;
        v_segment3                    NUMBER := 0;
        v_segment4                    NUMBER := 0;
        v_segment5                    NUMBER := 0;
        v_segment6                    NUMBER := 0;
        v_segment7                    NUMBER := 0;
        v_segment8                    NUMBER := 0;
        l_asn_count                   NUMBER := 0;
        l_reversal_count              NUMBER := 0;


        v_layout                      BOOLEAN;
        v_request_status              BOOLEAN;
        v_phase                       VARCHAR2 (2000);
        v_wait_status                 VARCHAR2 (2000);
        v_dev_phase                   VARCHAR2 (2000);
        v_dev_status                  VARCHAR2 (2000);
        v_message                     VARCHAR2 (2000);
        v_req_id                      NUMBER;
        v_resp_appl_id                NUMBER;
        v_resp_id                     NUMBER;
        v_user_id                     NUMBER;
        v_err_stat                    VARCHAR2 (1);
        v_err_msg                     VARCHAR2 (2000);
        l_int_count                   NUMBER;
        l_adj_amount                  NUMBER;          --Added per CCR0006936-

        v_region                      VARCHAR2 (10);              --CCR0007979
        l_ou                          NUMBER;
        v_reverse_intransit_context   VARCHAR2 (100);

        --Begin CCR0007979
        CURSOR c_regions IS
            SELECT hr.organization_id org_id, hr.attribute7 region
              FROM hr_all_organization_units hr
             WHERE     hr.attribute7 IS NOT NULL
                   AND (hr.organization_id = p_ou OR p_ou IS NULL);

        --End CCR0007979

        CURSOR c_po_asns IS
            SELECT rsh.Shipment_num AS Shipment_num, rsl.Shipment_line_Id AS Shipment_line_Id, msib.segment1 AS Item_Num,
                   rsl.quantity_shipped AS Quantity, rsh.creation_date AS asn_creation_date, ood.set_of_books_id AS ledger_id,
                   msib.organization_id AS organization_id, poh.po_header_id AS po_header_id, poh.segment1 AS po_num,
                   pol.unit_price AS unit_price, msib.inventory_item_id AS inventory_item_id, rsl.po_line_id AS po_line_id,
                   rsl.po_line_location_id AS po_line_location_id, --Changes as per CR#54starts
                                                                   GL.CURRENCY_CODE, gl.chart_of_accounts_id,
                   pol.attribute12 first_sale           --Added per CCR0006936
              --Changes as per CR#54ends
              FROM rcv_shipment_headers rsh, rcv_shipment_lines rsl, mtl_system_items_b msib,
                   po_headers_all poh, po_lines_all pol, org_organization_definitions ood,
                   gl_ledgers gl                        --Changes as per CR#54
             WHERE     rsl.shipment_header_id = rsh.shipment_header_id
                   AND poh.po_header_id = rsl.po_header_id
                   AND poh.po_header_id = pol.po_header_id
                   AND pol.PO_LINE_ID = rsl.PO_LINE_ID
                   AND msib.inventory_item_id = rsl.item_id
                   AND msib.ORGANIZATION_ID = rsl.TO_ORGANIZATION_ID
                   --  AND rsl.shipment_line_status_code = 'EXPECTED' --commented as per CR#54
                   AND rsl.source_document_code = 'PO'
                   AND rsh.asn_type = 'ASN'
                   AND ood.organization_id = rsl.TO_ORGANIZATION_ID
                   ---changes as per CR#54 starts
                   AND ood.set_of_books_id = gl.ledger_id
                   AND ood.operating_unit = poh.org_id
                   --change starts for defect#749
                   --AND NVL (rsl.attribute2, 'N') = 'N'
                   AND NVL (rsl.attribute5, 'N') = 'N'
                   --change ends for defect#749
                   AND poh.org_id = l_ou          ---changes as per CR#54 ends
                                        /*                AND poh.org_id IN (SELECT organization_id
                                                              FROM hr_operating_units
                                                             WHERE name = 'Deckers US OU')
                                         AND rsl.creation_date >=
                                                NVL (
                                                   (SELECT MAX (fcr.actual_completion_date)
                                                      FROM fnd_concurrent_requests fcr,
                                                           fnd_concurrent_programs fcp
                                                     WHERE     fcr.concurrent_program_id =
                                                                  fcp.concurrent_program_id
                                                           AND fcr.status_code = 'C'
                                                           AND fcr.phase_code = 'C'
                                                           AND fcr.ARGUMENT1 IS NULL
                                                           AND fcp.concurrent_program_name =
                                                                  'XXDOPO_AUTO_IN_TRANSIT'),
                                                   '01-JAN-2000')*/
                                        --commented as per CR#54
                                        ;

        CURSOR c_fail_asns IS
            SELECT rsh.Shipment_num AS Shipment_num, rsl.Shipment_line_Id AS Shipment_line_Id, msib.segment1 AS Item_Num,
                   rsl.quantity_shipped AS Quantity, rsh.creation_date AS asn_creation_date, ood.set_of_books_id AS ledger_id,
                   msib.organization_id AS organization_id, poh.po_header_id AS po_header_id, poh.segment1 AS po_num,
                   pol.unit_price AS unit_price, msib.inventory_item_id AS inventory_item_id, rsl.po_line_id AS po_line_id,
                   rsl.po_line_location_id AS po_line_location_id, --Changes as per CR#54starts
                                                                   GL.CURRENCY_CODE, gl.chart_of_accounts_id,
                   pol.attribute12 first_sale           --Added per CCR0006936
              --Changes as per CR#54ends
              FROM rcv_shipment_headers rsh, rcv_shipment_lines rsl, mtl_system_items_b msib,
                   po_headers_all poh, po_lines_all pol, org_organization_definitions ood,
                   gl_ledgers gl                          --added as per CR#54
             WHERE     rsl.shipment_header_id = rsh.shipment_header_id
                   AND poh.po_header_id = rsl.po_header_id
                   AND poh.po_header_id = pol.po_header_id
                   AND pol.PO_LINE_ID = rsl.PO_LINE_ID
                   AND msib.inventory_item_id = rsl.item_id
                   AND msib.ORGANIZATION_ID = rsl.TO_ORGANIZATION_ID
                   --AND rsl.shipment_line_status_code = 'EXPECTED'--commented as per CR#54
                   AND rsl.source_document_code = 'PO'
                   AND rsh.asn_type = 'ASN'
                   AND ood.organization_id = rsl.TO_ORGANIZATION_ID
                   /*AND poh.org_id IN (SELECT organization_id
                                        FROM hr_operating_units
                                       WHERE name = 'Deckers US OU')*/
                   --commented as per CR#54
                   AND rsh.Shipment_num = p_shipment_number
                   ---changes as per CR#54 starts
                   --change starts for defect#749
                   --AND NVL (rsl.attribute2, 'N') = 'N'
                   AND NVL (rsl.attribute5, 'N') = 'N'
                   --change ends for defect#749
                   AND ood.set_of_books_id = gl.ledger_id
                   AND ood.operating_unit = poh.org_id
                   AND poh.org_id = l_ou
                   ---changes as per CR#54 ends
                   AND NOT EXISTS
                           (SELECT *
                              FROM gl_je_lines
                             WHERE     1 = 1
                                   AND context =
                                       'In-Transit Journal ' || v_region --CCR0007979
                                   AND attribute1 = rsl.Shipment_line_Id);

        --Begin CCR0006936 -- Updated SQL for multiple receipt transactions
        CURSOR c_po_recvs IS
              /*  SELECT rt.transaction_id AS transaction_id,
                       rt.shipment_line_id AS shipment_line_id,
                       -- rsl.quantity_shipped AS quantity_shipped,
                       rsh.Shipment_num AS Shipment_num,
                       rt.quantity AS Transaction_quantity,
                       rt.Transaction_date AS Transaction_date,
                       -- rsl.quantity_received AS quantity_received,--commented as per CR#54
                       --Change as per CR#54 starts
                       NVL (
                          (SELECT SUM (rt.quantity)
                             FROM rcv_transactions rt
                            WHERE     1 = 1
                                  AND rt.shipment_header_id = rsh.shipment_header_id
                                  AND rt.shipment_line_id = rsl.shipment_line_id
                                  AND rt.transaction_type = 'RECEIVE'
                                  AND rt.SOURCE_DOCUMENT_CODE = 'PO'),
                          0)
                          AS quantity_received,
                       NVL (rsl.quantity_shipped, 0) AS quantity_shipped,
                       -- LAST_TRANS -- Start
                       /*
                                       (SELECT MAX (rt1.Transaction_date)
                                          FROM rcv_transactions rt1
                                         WHERE     rt1.shipment_line_id = rsl.shipment_line_id
                                         AND rt1.transaction_type = 'RECEIVE'
                                         AND rt1.SOURCE_DOCUMENT_CODE = 'PO'
                                          --change starts for defect#749
                                       --AND NVL (rt1.attribute5, 'N') = 'N'
                                        AND NVL (rt1.attribute3, 'N') = 'N'
                                       --change ends for defect#749
                                       )
                                          AS max_transaction_date,

                       (SELECT MAX (rt1.Transaction_id)
                          FROM rcv_transactions rt1
                         WHERE     rt1.shipment_line_id = rsl.shipment_line_id
                               AND rt1.transaction_type = 'RECEIVE'
                               AND rt1.SOURCE_DOCUMENT_CODE = 'PO'
                               --change starts for defect#749
                               --AND NVL (rt1.attribute5, 'N') = 'N'
                               AND NVL (rt1.attribute3, 'N') = 'N' --change ends for defect#749
                                                                  )
                          AS max_transaction_id,
                       -- LAST_TRANS -- End
                       --Change as per CR#54 ends
                       rt.po_header_id AS po_header_id,
                       rt.organization_id AS organization_id,
                       poh.segment1 AS po_num,
                       rt.po_unit_price AS po_unit_price,
                       msib.inventory_item_id AS inventory_item_id,
                       msib.segment1 AS Item_Num,
                       gl.code_combination_id AS code_combination_id,
                       gl.entered_dr AS entered_dr,
                       gl.entered_cr AS entered_cr,
                       gl.description AS description,
                       gl.ledger_id AS ledger_id,
                       rsl.po_line_id AS po_line_id,
                       rsl.po_line_location_id AS po_line_location_id,
                       --Changes as per CR#54starts
                       GLl.CURRENCY_CODE,
                       gll.chart_of_accounts_id,
                       --Changes as per CR#54ends
                       -- ELEMENTS_IN_DFF - Start
                       TO_NUMBER (rsl.ATTRIBUTE6) unit_duty_amt,
                       TO_NUMBER (rsl.ATTRIBUTE7) unit_freight_amt,
                       TO_NUMBER (rsl.ATTRIBUTE8) unit_freightdu_amt,
                       TO_NUMBER (rsl.ATTRIBUTE9) unit_ohduty_amt,
                       TO_NUMBER (rsl.ATTRIBUTE10) unit_oh_nonduty_amt,
                       TO_NUMBER (rsl.ATTRIBUTE11) unit_overheads_amt,
                       rsl.attribute2 asn_first_sale          --Added per  CCR0006936
                  -- ELEMENTS_IN_DFF - End
                  FROM rcv_transactions rt,
                       mtl_system_items_b msib,
                       org_organization_definitions ood,
                       rcv_shipment_headers rsh,
                       rcv_shipment_lines rsl,
                       po_headers_all poh,
                       gl_je_lines gl,
                       gl_ledgers gll                            --added as per CR#54
                 WHERE     1 = 1
                       AND gl.attribute1 = rt.shipment_line_id
                       AND gl.ledger_id = ood.set_of_books_id
                       AND gl.context = 'In-Transit Journal US'
                       AND rt.organization_id = ood.organization_id
                       AND msib.organization_id = ood.organization_id
                       AND rt.shipment_header_id = rsh.shipment_header_id
                       AND rt.shipment_line_id = rsl.shipment_line_id
                       AND rsl.shipment_header_id = rsh.shipment_header_id
                       AND msib.inventory_item_id = rsl.item_id
                       AND msib.ORGANIZATION_ID = rsl.TO_ORGANIZATION_ID
                       AND rt.transaction_type = 'RECEIVE'
                       AND rt.SOURCE_DOCUMENT_CODE = 'PO'
                       AND poh.po_header_id = rt.po_header_id
                       ---Change as per CR#54 starts
                       AND ood.set_of_books_id = gll.ledger_id
                       AND ood.operating_unit = poh.org_id
                       AND rsh.Shipment_num =
                              NVL (p_shipment_number, rsh.Shipment_num)
                       --change starts for defect#749
                       --AND NVL (rt.attribute5, 'N') = 'N'
                       AND NVL (rt.attribute3, 'N') = 'N'
                       --change ends for defect#749
                       AND poh.org_id = NVL (p_ou,
                                             (SELECT organization_id
                                                FROM hr_operating_units
                                               WHERE name = 'Deckers US OU'))
                       AND NOT EXISTS
                                  (SELECT 1
                                     FROM gl_je_lines
                                    WHERE     1 = 1
                                          AND context =
                                                 'Reverse In-Transit Journal US'
                                          AND attribute1 = rt.transaction_id) ---Change as per CR#54 ends
                                                                             /*AND ood.operating_unit IN (SELECT organization_id
                                                                                                          FROM hr_operating_units
                                                                                                         WHERE name = 'Deckers US OU')
                                                                             AND rt.creation_date >=
                                                                                    NVL (
                                                                                       (SELECT MAX (fcr.actual_completion_date)
                                                                                          FROM fnd_concurrent_requests fcr,
                                                                                               fnd_concurrent_programs fcp
                                                                                         WHERE     fcr.concurrent_program_id =
                                                                                                      fcp.concurrent_program_id
                                                                                               AND fcr.status_code = 'C'
                                                                                               AND fcr.phase_code = 'C'
                                                                                               AND fcp.concurrent_program_name =
                                                                                                      'XXDOPO_AUTO_IN_TRANSIT'),
                                                                                       '01-JAN-2000')
                                                                             --commented as per CR#54
          ;
          */
              SELECT pha.segment1
                         po_num,
                     rt.transaction_id,
                     rt.po_header_id,
                     rt.GROUP_ID,
                     rt.shipment_line_id,
                     rt.organization_id,
                     rt.po_unit_price,
                     rt.quantity
                         transaction_quantity,
                     rt.transaction_date,
                     msib.inventory_item_id,
                     msib.segment1
                         item_num,
                     gjl.code_combination_id,
                     gjl.entered_cr,
                     gjl.entered_dr,
                     gjl.description,
                     gjl.ledger_id,
                     gll.currency_code,
                     gll.chart_of_accounts_id,
                     NVL (rsl.quantity_shipped, 0)
                         quantity_shipped,
                     rsl.quantity_received,
                     rsl.po_line_id,
                     rsl.po_line_location_id,
                     rsh.shipment_num,
                     --START : CCR0007955
                     NVL (
                         (SELECT SUM (rt.quantity)
                            FROM rcv_transactions rt
                           WHERE     rt.transaction_type = 'CORRECT'
                                 AND rt.destination_type_code = 'RECEIVING'
                                 AND rsl.shipment_line_id = rt.shipment_line_id
                                 AND rt.comments IS NULL),
                         0)
                         pending_corrections,
                     --END : CCR0007955
                     TO_NUMBER (rsl.ATTRIBUTE6)
                         unit_duty_amt,
                     TO_NUMBER (rsl.ATTRIBUTE7)
                         unit_freight_amt,
                     TO_NUMBER (rsl.ATTRIBUTE8)
                         unit_freightdu_amt,
                     TO_NUMBER (rsl.ATTRIBUTE9)
                         unit_ohduty_amt,
                     TO_NUMBER (rsl.ATTRIBUTE10)
                         unit_oh_nonduty_amt,
                     TO_NUMBER (rsl.ATTRIBUTE11)
                         unit_overheads_amt,
                     rsl.attribute2
                         asn_first_sale,
                       NVL (rsl.quantity_received, 0)
                     - SUM (quantity)
                           OVER (PARTITION BY rt.shipment_line_id, gjl.description
                                 ORDER BY rt.shipment_line_id)
                         AS prior_rcv_Amt,
                     SUM (rt.quantity)
                         OVER (PARTITION BY rt.shipment_line_id, gjl.description
                               ORDER BY rt.transaction_id)
                         AS Running_Amt,
                     MAX (rt.transaction_id)
                         OVER (PARTITION BY rt.GROUP_ID, rt.shipment_line_id
                               ORDER BY rt.GROUP_ID, rt.shipment_line_id)
                         AS max_transaction_id
                FROM (SELECT *
                        FROM rcv_transactions
                       WHERE     transaction_type = 'RECEIVE'
                             AND NVL (attribute3, 'N') = 'N'
                             AND source_document_code = 'PO') rt,
                     gl.gl_je_lines gjl,
                     gl.gl_ledgers gll,
                     org_organization_definitions ood,
                     rcv_shipment_headers rsh,
                     rcv_shipment_lines rsl,
                     po_headers_all pha,
                     (SELECT *
                        FROM mtl_system_items_b
                       WHERE organization_id = 106) msib
               WHERE     1 = 1
                     AND TO_NUMBER (gjl.attribute1) = rt.shipment_line_id
                     AND gjl.context = 'In-Transit Journal ' || v_region --CCR0007979
                     AND rt.organization_id = ood.organization_id
                     AND gll.ledger_id = ood.set_of_books_id
                     AND gjl.ledger_id = gll.ledger_id
                     AND rsl.shipment_header_id = rsh.shipment_header_id
                     AND rt.shipment_line_id = rsl.shipment_line_id
                     AND rsl.po_header_id = pha.po_header_id
                     AND rsl.item_id = msib.inventory_item_id
                     AND rsh.shipment_num =
                         NVL (p_shipment_number, rsh.shipment_num)
                     AND pha.org_id = l_ou
                     AND NOT EXISTS
                             (SELECT 1
                                FROM gl_je_lines
                               WHERE     1 = 1
                                     AND context =
                                            'Reverse In-Transit Journal '
                                         || v_region              --CCR0007979
                                     AND attribute1 = rt.transaction_id)
            ORDER BY rsl.shipment_header_id, rsl.shipment_line_id, rt.transaction_id;
    --End CCR0006936

    BEGIN
        fnd_file.put_line (
            fnd_file.output,
               'Deckers Purchasing Intransit Accrual program'
            || CHR (13)
            || CHR (10));
        fnd_file.put_line (
            fnd_file.output,
               'Date: '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
            || CHR (13)
            || CHR (10));
        fnd_file.put_line (fnd_file.output, CHR (13) || CHR (10));
        fnd_file.put_line (fnd_file.output, CHR (13) || CHR (10));

        IF p_ou IS NOT NULL
        THEN
            v_region   := get_intransit_region (p_ou);            --CCR0007979

            IF v_region IS NULL
            THEN
                fnd_file.put_line (
                    fnd_file.output,
                    'OU : ' || p_ou || ' Is not setup for Intransit process');
                RETURN;
            END IF;
        END IF;



        BEGIN
            fnd_file.put_line (
                fnd_file.output,
                   RPAD ('REGION', 10, ' ')                       --CCR0007979
                || RPAD ('PO_NUMBER', 12, ' ')
                || RPAD ('ASN(SHIPMENT_NUMBER)', 25, ' ')
                || RPAD ('SHIP_ITEM', 20, ' ')
                || RPAD ('PO_UNIT_PRICE', 17, ' ')
                || RPAD ('AMOUNT', 10, ' ')
                || RPAD ('JE_BATCH_NAME', 47, ' ')
                || RPAD ('JOURNAL_NAME', 40, ' ')
                || RPAD ('JOURNAL_LINE_DESCRIPTION', 50, ' ')
                || RPAD ('CODE_COMBINATION', 20, ' ')
                || CHR (13)
                || CHR (10));
            fnd_file.put_line (fnd_file.output,
                               RPAD ('=', 244, '=') || CHR (13) || CHR (10));

            --CCR0007979
            FOR region_rec IN c_regions
            LOOP
                v_region   := region_rec.region;
                l_ou       := region_rec.org_id;


                fnd_file.put_line (
                    fnd_file.LOG,
                    ' REGION : ' || v_region || ' OU : ' || l_ou); --CCR0007979

                --begin  CCR0006936
                IF p_cst_adj_only = 'Y'
                THEN
                    create_adjustments_interface (psqlstat, perrproc, p_shipment_number
                                                  , l_ou, v_region); --CCR0007979
                --End  CCR0006936
                ELSE
                    IF p_shipment_number IS NOT NULL
                    THEN
                        fnd_file.put_line (fnd_file.LOG, p_shipment_number);

                        FOR c_fail_asn IN c_fail_asns
                        LOOP
                            insert_into_inteface (
                                p_org_id          => c_fail_asn.organization_id,
                                p_coc_id          => c_fail_asn.chart_of_accounts_id, --added as per CR#54
                                p_inv_item_id     =>
                                    c_fail_asn.inventory_item_id,
                                p_header_id       => c_fail_asn.po_header_id,
                                p_line_id         => c_fail_asn.po_line_id,
                                p_line_location_id   =>
                                    c_fail_asn.po_line_location_id,
                                p_Quantity        => c_fail_asn.Quantity,
                                p_shipment_num    => c_fail_asn.shipment_num,
                                p_ledgerid        => c_fail_asn.ledger_id,
                                p_datecreated     =>
                                    c_fail_asn.asn_creation_date,
                                p_currency_code   => c_fail_asn.currency_code,
                                p_shipmentlineid   =>
                                    c_fail_asn.Shipment_line_Id,
                                p_ponum           => c_fail_asn.po_num,
                                p_itemnum         => c_fail_asn.Item_Num,
                                P_unitprice       => c_fail_asn.unit_price,
                                p_firstsale       =>
                                    TO_NUMBER (c_fail_asn.first_sale), --Added per  CCR0006936
                                p_region          => v_region);   --CCR0007979

                            --Change as per CR#54 starts
                            l_asn_count   := l_asn_count + 1;

                            -- COMMIT_BATCH_SIZE - Start
                            --IF l_asn_count >= 500
                            IF l_asn_count >= g_commit_batch_size
                            -- COMMIT_BATCH_SIZE - End
                            THEN
                                COMMIT;
                                l_asn_count   := 0;
                            END IF;
                        --Change as per CR#54 ends
                        END LOOP;
                    ELSE
                        fnd_file.put_line (fnd_file.LOG,
                                           ' Starting of c_po_asns cursor');

                        FOR c_po_asn IN c_po_asns
                        LOOP
                            fnd_file.put_line (
                                fnd_file.LOG,
                                ' Inserting Shipment_line_Id' || c_po_asn.Shipment_line_Id);
                            insert_into_inteface (
                                p_org_id          => c_po_asn.organization_id,
                                p_coc_id          => c_po_asn.chart_of_accounts_id, --added as per CR#54
                                p_inv_item_id     => c_po_asn.inventory_item_id,
                                p_header_id       => c_po_asn.po_header_id,
                                p_line_id         => c_po_asn.po_line_id,
                                p_line_location_id   =>
                                    c_po_asn.po_line_location_id,
                                p_Quantity        => c_po_asn.Quantity,
                                p_shipment_num    => c_po_asn.shipment_num,
                                p_ledgerid        => c_po_asn.ledger_id,
                                p_datecreated     => c_po_asn.asn_creation_date,
                                p_currency_code   => c_po_asn.currency_code,
                                p_shipmentlineid   =>
                                    c_po_asn.Shipment_line_Id,
                                p_ponum           => c_po_asn.po_num,
                                p_itemnum         => c_po_asn.Item_Num,
                                P_unitprice       => c_po_asn.unit_price,
                                p_firstsale       =>
                                    TO_NUMBER (c_po_asn.first_sale),
                                p_region          => v_region); --Added per  CCR0006936, --CCR0007979

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   ' After Inserting Shipment_line_Id'
                                || c_po_asn.Shipment_line_Id);
                            --Change as per CR#54 starts
                            l_asn_count   := l_asn_count + 1;

                            -- COMMIT_BATCH_SIZE - Start
                            IF l_asn_count >= g_commit_batch_size
                            --IF l_asn_count >= 500
                            -- COMMIT_BATCH_SIZE - End
                            THEN
                                COMMIT;
                                l_asn_count   := 0;
                            END IF;
                        --Change as per CR#54 ends

                        END LOOP;
                    END IF;

                    FOR c_po_recv IN c_po_recvs
                    LOOP
                        BEGIN
                            v_reverse_intransit_context   :=
                                   g_reverse_intransit_context
                                || ' '
                                || v_region;                      --CCR0007979
                            --Initial RSL values:
                            fnd_file.put_line (fnd_file.LOG,
                                               'RSL reversal entries');
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'RSL ATTR  6 :' || c_po_recv.unit_duty_amt); --Current GL unit duty
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'RSL ATTR 11 :' || c_po_recv.unit_overheads_amt); --Current GL unit OH


                            --Begin CCR0006936
                            --Get running amount as current running amount for receive set plus prior reveived to date
                            l_running_amount   :=
                                  c_po_recv.running_amt
                                + c_po_recv.prior_rcv_Amt
                                - c_po_recv.pending_corrections; ---- CCR0007955

                            --if running amount is less than ASN shipped then there is room for entire transaction to be posted
                            IF l_running_amount <= c_po_recv.quantity_shipped
                            THEN
                                v_quantity   :=
                                    c_po_recv.transaction_quantity;
                            --If the over receive amount is less than current transaction quantity the post partial balance
                            ELSIF   l_running_amount
                                  - c_po_recv.quantity_shipped <
                                  c_po_recv.transaction_quantity
                            THEN
                                --Line aready over received in excess of transaction balance . Post 0 quantity
                                v_quantity   :=
                                      c_po_recv.transaction_quantity
                                    - (l_running_amount - c_po_recv.quantity_shipped);
                            ELSE
                                v_quantity   := 0;
                            END IF;


                            /*

                                              IF     c_po_recv.quantity_received >
                                                        c_po_recv.quantity_shipped --               AND c_po_recv.transaction_date =                       -- LAST_TRANS - Start
                                                 --                      c_po_recv.max_transaction_date      --added as per CR#54
                                                 AND c_po_recv.transaction_id =
                                                        c_po_recv.max_transaction_id
                                              THEN
                                                 --v_quantity := c_po_recv.quantity_shipped;--commented as per CR#54
                                                 v_quantity :=
                                                      c_po_recv.Transaction_quantity
                                                    - (  c_po_recv.quantity_received
                                                       - c_po_recv.quantity_shipped); --added as per CR#54
                                              ELSE
                                                 --v_quantity := c_po_recv.quantity_received; --commented as per CR#54
                                                 v_quantity := c_po_recv.Transaction_quantity; --added as per CR#54
                                              END IF;
                                              */
                            --End CCR0006936

                            fnd_file.put_line (
                                fnd_file.LOG,
                                ' Processing Transaction : ' || c_po_recv.transaction_id);


                            IF c_po_recv.description LIKE 'DUTY%'
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       ' Duty - Processing Transaction : '
                                    || c_po_recv.transaction_id);

                                --Change as per CR#54 starts
                                --ELEMENTS_IN_DFF - Start
                                IF c_po_recv.unit_duty_amt IS NOT NULL
                                THEN
                                    l_duty_cost   := c_po_recv.unit_duty_amt;
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Unit Duty Amount : '
                                        || l_duty_cost
                                        || ' - From cursor');
                                ELSE
                                    --ELEMENTS_IN_DFF - End
                                    l_duty_cost   :=
                                        get_amount (
                                            p_cost   => 'DUTY',
                                            p_organization_id   =>
                                                c_po_recv.organization_id,
                                            p_inventory_item_id   =>
                                                c_po_recv.inventory_item_id,
                                            p_po_header_id   =>
                                                c_po_recv.po_header_id,
                                            p_po_line_id   =>
                                                c_po_recv.po_line_id,
                                            p_po_line_location_id   =>
                                                c_po_recv.po_line_location_id);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Unit Duty Amount : '
                                        || l_duty_cost
                                        || ' - From function');
                                END IF;

                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Quantity received : ' || v_quantity);

                                l_duty_amt   :=
                                    ROUND (l_duty_cost * v_quantity, 2);

                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Duty Amount : ' || v_quantity);

                                /* l_duty_amt :=
                                   (c_po_recv.entered_cr / c_po_recv.quantity_shipped)
                                 * v_quantity;*/
                                --commented as per CR#54

                                --Change as per CR#54 ends
                                insert_into_gl_iface (
                                    p_ledger_id       => c_po_recv.ledger_id,
                                    p_date_created    =>
                                        c_po_recv.transaction_date,
                                    --p_currency_code         => 'USD',--commented as per CR#54
                                    p_currency_code   =>
                                        c_po_recv.currency_code, --added as per CR#54
                                    p_code_combination_id   =>
                                        c_po_recv.code_combination_id,
                                    p_debit_amount    => l_duty_amt,
                                    p_credit_amount   => NULL,
                                    p_batch_name      => g_reverse_batch_name,
                                    p_batch_desc      => g_reverse_batch_name,
                                    p_journal_name    =>
                                           c_po_recv.Shipment_num
                                        || '-'
                                        || c_po_recv.transaction_Id,
                                    p_journal_desc    =>
                                           g_reverse_batch_name
                                        || '-'
                                        || c_po_recv.Shipment_num,
                                    p_line_desc       =>
                                           'DUTY'
                                        || '-'
                                        || c_po_recv.Shipment_num
                                        || ' '
                                        || c_po_recv.transaction_Id,
                                    p_context         =>
                                        v_reverse_intransit_context,
                                    P_attribute1      =>
                                        c_po_recv.transaction_Id);


                                SELECT segment1, segment2, segment3,
                                       segment4, segment5, segment6,
                                       segment7, segment8
                                  INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                                 v_segment5, v_segment6, v_segment7,
                                                 v_segment8
                                  FROM gl_code_combinations
                                 WHERE code_combination_id =
                                       c_po_recv.code_combination_id;

                                fnd_file.put_line (
                                    fnd_file.output,
                                       RPAD (v_region, 10, ' ')   --CCR0007979
                                    || RPAD (c_po_recv.po_num, 12, ' ')
                                    || RPAD (c_po_recv.Shipment_num, 25, ' ')
                                    || RPAD (c_po_recv.Item_Num, 20, ' ')
                                    || RPAD (c_po_recv.po_unit_price,
                                             17,
                                             ' ')
                                    || RPAD (l_duty_amt, 10, ' ')
                                    || RPAD (g_reverse_batch_name, 47, ' ')
                                    || RPAD (
                                              c_po_recv.Shipment_num
                                           || '-'
                                           || c_po_recv.transaction_Id,
                                           30,
                                           ' ')
                                    || RPAD (
                                              'DUTY'
                                           || '-'
                                           || c_po_recv.Shipment_num
                                           || ' '
                                           || c_po_recv.transaction_Id,
                                           45,
                                           ' ')
                                    || RPAD (
                                              v_segment1
                                           || '.'
                                           || v_segment2
                                           || '.'
                                           || v_segment3
                                           || '.'
                                           || v_segment4
                                           || '.'
                                           || v_segment5
                                           || '.'
                                           || v_segment6
                                           || '.'
                                           || v_segment7
                                           || '.'
                                           || v_segment8,
                                           60,
                                           ' ')
                                    || CHR (13)
                                    || CHR (10));
                            ELSIF c_po_recv.description LIKE 'FRGT%'
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       ' Freight - Processing Transaction : '
                                    || c_po_recv.transaction_id);

                                --Change as per CR#54 starts
                                --ELEMENTS_IN_DFF - Start
                                IF c_po_recv.unit_freight_amt IS NOT NULL
                                THEN
                                    l_freight_cost   :=
                                        c_po_recv.unit_freight_amt;
                                ELSE
                                    --ELEMENTS_IN_DFF - End
                                    l_freight_cost   :=
                                        get_amount (
                                            p_cost   => 'FREIGHT',
                                            p_organization_id   =>
                                                c_po_recv.organization_id,
                                            p_inventory_item_id   =>
                                                c_po_recv.inventory_item_id,
                                            p_po_header_id   =>
                                                c_po_recv.po_header_id,
                                            p_po_line_id   =>
                                                c_po_recv.po_line_id,
                                            p_po_line_location_id   =>
                                                c_po_recv.po_line_location_id);
                                END IF;

                                l_freight_amt   :=
                                    ROUND (l_freight_cost * v_quantity, 2);

                                /*l_freight_amt :=
                                   (c_po_recv.entered_cr / c_po_recv.quantity_shipped)
                                 * v_quantity;*/
                                --commented as per CR#54

                                --Change as per CR#54 ends

                                insert_into_gl_iface (
                                    p_ledger_id       => c_po_recv.ledger_id,
                                    p_date_created    =>
                                        c_po_recv.transaction_date,
                                    --p_currency_code         => 'USD',--commented as per CR#54
                                    p_currency_code   =>
                                        c_po_recv.currency_code, --added as per CR#54
                                    p_code_combination_id   =>
                                        c_po_recv.code_combination_id,
                                    p_debit_amount    => l_freight_amt,
                                    p_credit_amount   => NULL,
                                    p_batch_name      => g_reverse_batch_name,
                                    p_batch_desc      => g_reverse_batch_name,
                                    p_journal_name    =>
                                           c_po_recv.Shipment_num
                                        || '-'
                                        || c_po_recv.transaction_Id,
                                    p_journal_desc    =>
                                           g_reverse_batch_name
                                        || '-'
                                        || c_po_recv.Shipment_num,
                                    p_line_desc       =>
                                           'FRGT'
                                        || '-'
                                        || c_po_recv.Shipment_num
                                        || ' '
                                        || c_po_recv.transaction_Id,
                                    p_context         =>
                                        v_reverse_intransit_context,
                                    P_attribute1      =>
                                        c_po_recv.transaction_Id);

                                SELECT segment1, segment2, segment3,
                                       segment4, segment5, segment6,
                                       segment7, segment8
                                  INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                                 v_segment5, v_segment6, v_segment7,
                                                 v_segment8
                                  FROM gl_code_combinations
                                 WHERE code_combination_id =
                                       c_po_recv.code_combination_id;

                                fnd_file.put_line (
                                    fnd_file.output,
                                       RPAD (v_region, 10, ' ')   --CCR0007979
                                    || RPAD (c_po_recv.po_num, 12, ' ')
                                    || RPAD (c_po_recv.Shipment_num, 25, ' ')
                                    || RPAD (c_po_recv.Item_Num, 20, ' ')
                                    || RPAD (c_po_recv.po_unit_price,
                                             17,
                                             ' ')
                                    || RPAD (l_freight_amt, 10, ' ')
                                    || RPAD (g_reverse_batch_name, 47, ' ')
                                    || RPAD (
                                              c_po_recv.Shipment_num
                                           || '-'
                                           || c_po_recv.transaction_Id,
                                           30,
                                           ' ')
                                    || RPAD (
                                              'FRGT'
                                           || '-'
                                           || c_po_recv.Shipment_num
                                           || ' '
                                           || c_po_recv.transaction_Id,
                                           45,
                                           ' ')
                                    || RPAD (
                                              v_segment1
                                           || '.'
                                           || v_segment2
                                           || '.'
                                           || v_segment3
                                           || '.'
                                           || v_segment4
                                           || '.'
                                           || v_segment5
                                           || '.'
                                           || v_segment6
                                           || '.'
                                           || v_segment7
                                           || '.'
                                           || v_segment8,
                                           60,
                                           ' ')
                                    || CHR (13)
                                    || CHR (10));
                            ELSIF c_po_recv.description LIKE 'FREIGHT_DU%'
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       ' Freight DU - Processing Transaction : '
                                    || c_po_recv.transaction_id);

                                --Change as per CR#54 starts
                                --ELEMENTS_IN_DFF - Start
                                IF c_po_recv.unit_freightdu_amt IS NOT NULL
                                THEN
                                    l_freightdu_cost   :=
                                        c_po_recv.unit_freightdu_amt;
                                ELSE
                                    --ELEMENTS_IN_DFF - End
                                    l_freightdu_cost   :=
                                        get_amount (
                                            p_cost   => 'FREIGHT DU',
                                            p_organization_id   =>
                                                c_po_recv.organization_id,
                                            p_inventory_item_id   =>
                                                c_po_recv.inventory_item_id,
                                            p_po_header_id   =>
                                                c_po_recv.po_header_id,
                                            p_po_line_id   =>
                                                c_po_recv.po_line_id,
                                            p_po_line_location_id   =>
                                                c_po_recv.po_line_location_id);
                                END IF;

                                l_freightdu_amt   :=
                                    ROUND (l_freightdu_cost * v_quantity, 2);

                                /*l_freightdu_amt :=
                                   (c_po_recv.entered_cr / c_po_recv.quantity_shipped)
                                 * v_quantity;*/
                                --commented as per CR#54

                                --Change as per CR#54 ends


                                l_freightdu_amt   :=
                                      (c_po_recv.entered_cr / c_po_recv.quantity_shipped)
                                    * v_quantity;

                                insert_into_gl_iface (
                                    p_ledger_id       => c_po_recv.ledger_id,
                                    p_date_created    =>
                                        c_po_recv.transaction_date,
                                    --p_currency_code         => 'USD',--commented as per CR#54
                                    p_currency_code   =>
                                        c_po_recv.currency_code, --added as per CR#54
                                    p_code_combination_id   =>
                                        c_po_recv.code_combination_id,
                                    p_debit_amount    => l_freightdu_amt,
                                    p_credit_amount   => NULL,
                                    p_batch_name      => g_reverse_batch_name,
                                    p_batch_desc      => g_reverse_batch_name,
                                    p_journal_name    =>
                                           c_po_recv.Shipment_num
                                        || '-'
                                        || c_po_recv.transaction_Id,
                                    p_journal_desc    =>
                                           g_reverse_batch_name
                                        || '-'
                                        || c_po_recv.Shipment_num,
                                    p_line_desc       =>
                                           'FREIGHT_DU'
                                        || '-'
                                        || c_po_recv.Shipment_num
                                        || ' '
                                        || c_po_recv.transaction_Id,
                                    p_context         =>
                                        v_reverse_intransit_context,
                                    P_attribute1      =>
                                        c_po_recv.transaction_Id);

                                SELECT segment1, segment2, segment3,
                                       segment4, segment5, segment6,
                                       segment7, segment8
                                  INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                                 v_segment5, v_segment6, v_segment7,
                                                 v_segment8
                                  FROM gl_code_combinations
                                 WHERE code_combination_id =
                                       c_po_recv.code_combination_id;

                                fnd_file.put_line (
                                    fnd_file.output,
                                       RPAD (v_region, 10, ' ')   --CCR0007979
                                    || RPAD (c_po_recv.po_num, 12, ' ')
                                    || RPAD (c_po_recv.Shipment_num, 25, ' ')
                                    || RPAD (c_po_recv.Item_Num, 20, ' ')
                                    || RPAD (c_po_recv.po_unit_price,
                                             17,
                                             ' ')
                                    || RPAD (l_freightdu_amt, 10, ' ')
                                    || RPAD (g_reverse_batch_name, 47, ' ')
                                    || RPAD (
                                              c_po_recv.Shipment_num
                                           || '-'
                                           || c_po_recv.transaction_Id,
                                           30,
                                           ' ')
                                    || RPAD (
                                              'FREIGHT_DU'
                                           || '-'
                                           || c_po_recv.Shipment_num
                                           || ' '
                                           || c_po_recv.transaction_Id,
                                           45,
                                           ' ')
                                    || RPAD (
                                              v_segment1
                                           || '.'
                                           || v_segment2
                                           || '.'
                                           || v_segment3
                                           || '.'
                                           || v_segment4
                                           || '.'
                                           || v_segment5
                                           || '.'
                                           || v_segment6
                                           || '.'
                                           || v_segment7
                                           || '.'
                                           || v_segment8,
                                           60,
                                           ' ')
                                    || CHR (13)
                                    || CHR (10));
                            ELSIF c_po_recv.description LIKE 'OH DUTY%'
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'OH Duty - Processing Transaction : '
                                    || c_po_recv.transaction_id);

                                --Change as per CR#54 starts
                                --ELEMENTS_IN_DFF - Start
                                IF c_po_recv.unit_ohduty_amt IS NOT NULL
                                THEN
                                    l_ohduty_cost   :=
                                        c_po_recv.unit_ohduty_amt;
                                ELSE
                                    --ELEMENTS_IN_DFF - End
                                    l_ohduty_cost   :=
                                        get_amount (
                                            p_cost   => 'OH DUTY',
                                            p_organization_id   =>
                                                c_po_recv.organization_id,
                                            p_inventory_item_id   =>
                                                c_po_recv.inventory_item_id,
                                            p_po_header_id   =>
                                                c_po_recv.po_header_id,
                                            p_po_line_id   =>
                                                c_po_recv.po_line_id,
                                            p_po_line_location_id   =>
                                                c_po_recv.po_line_location_id);
                                END IF;

                                l_ohduty_amt   :=
                                    ROUND (l_ohduty_cost * v_quantity, 2);
                                /*l_ohduty_amt :=
                                     (c_po_recv.entered_cr / c_po_recv.quantity_shipped)
                                   * v_quantity;*/
                                --Change as per CR#54 ends

                                insert_into_gl_iface (
                                    p_ledger_id       => c_po_recv.ledger_id,
                                    p_date_created    =>
                                        c_po_recv.transaction_date,
                                    --p_currency_code         => 'USD',--commented as per CR#54
                                    p_currency_code   =>
                                        c_po_recv.currency_code, --added as per CR#54
                                    p_code_combination_id   =>
                                        c_po_recv.code_combination_id,
                                    p_debit_amount    => l_ohduty_amt,
                                    p_credit_amount   => NULL,
                                    p_batch_name      => g_reverse_batch_name,
                                    p_batch_desc      => g_reverse_batch_name,
                                    p_journal_name    =>
                                           c_po_recv.Shipment_num
                                        || '-'
                                        || c_po_recv.transaction_Id,
                                    p_journal_desc    =>
                                           g_reverse_batch_name
                                        || '-'
                                        || c_po_recv.Shipment_num,
                                    p_line_desc       =>
                                           'OH DUTY'
                                        || '-'
                                        || c_po_recv.Shipment_num
                                        || ' '
                                        || c_po_recv.transaction_Id,
                                    p_context         =>
                                        v_reverse_intransit_context,
                                    P_attribute1      =>
                                        c_po_recv.transaction_Id);

                                SELECT segment1, segment2, segment3,
                                       segment4, segment5, segment6,
                                       segment7, segment8
                                  INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                                 v_segment5, v_segment6, v_segment7,
                                                 v_segment8
                                  FROM gl_code_combinations
                                 WHERE code_combination_id =
                                       c_po_recv.code_combination_id;

                                fnd_file.put_line (
                                    fnd_file.output,
                                       RPAD (v_region, 10, ' ')   --CCR0007979
                                    || RPAD (c_po_recv.po_num, 12, ' ')
                                    || RPAD (c_po_recv.Shipment_num, 25, ' ')
                                    || RPAD (c_po_recv.Item_Num, 20, ' ')
                                    || RPAD (c_po_recv.po_unit_price,
                                             17,
                                             ' ')
                                    || RPAD (l_ohduty_amt, 10, ' ')
                                    || RPAD (g_reverse_batch_name, 47, ' ')
                                    || RPAD (
                                              c_po_recv.Shipment_num
                                           || '-'
                                           || c_po_recv.transaction_Id,
                                           30,
                                           ' ')
                                    || RPAD (
                                              'OH DUTY'
                                           || '-'
                                           || c_po_recv.Shipment_num
                                           || ' '
                                           || c_po_recv.transaction_Id,
                                           45,
                                           ' ')
                                    || RPAD (
                                              v_segment1
                                           || '.'
                                           || v_segment2
                                           || '.'
                                           || v_segment3
                                           || '.'
                                           || v_segment4
                                           || '.'
                                           || v_segment5
                                           || '.'
                                           || v_segment6
                                           || '.'
                                           || v_segment7
                                           || '.'
                                           || v_segment8,
                                           60,
                                           ' ')
                                    || CHR (13)
                                    || CHR (10));
                            ELSIF c_po_recv.description LIKE 'OH NONDUTY%'
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'OH Non Duty - Processing Transaction : '
                                    || c_po_recv.transaction_id);

                                --Change as per CR#54 starts
                                --ELEMENTS_IN_DFF - Start
                                IF c_po_recv.unit_oh_nonduty_amt IS NOT NULL
                                THEN
                                    l_oh_nonduty_cost   :=
                                        c_po_recv.unit_oh_nonduty_amt;
                                ELSE
                                    --ELEMENTS_IN_DFF - End
                                    l_oh_nonduty_cost   :=
                                        get_amount (
                                            p_cost   => 'OH NONDUTY',
                                            p_organization_id   =>
                                                c_po_recv.organization_id,
                                            p_inventory_item_id   =>
                                                c_po_recv.inventory_item_id,
                                            p_po_header_id   =>
                                                c_po_recv.po_header_id,
                                            p_po_line_id   =>
                                                c_po_recv.po_line_id,
                                            p_po_line_location_id   =>
                                                c_po_recv.po_line_location_id);
                                END IF;

                                l_oh_nonduty_amt   :=
                                    ROUND (l_oh_nonduty_cost * v_quantity, 2);
                                /*l_oh_nonduty_amt :=
                                     (c_po_recv.entered_cr / c_po_recv.quantity_shipped)
                                   * v_quantity;*/
                                --Change as per CR#54 ends
                                insert_into_gl_iface (
                                    p_ledger_id       => c_po_recv.ledger_id,
                                    p_date_created    =>
                                        c_po_recv.transaction_date,
                                    --p_currency_code         => 'USD',--commented as per CR#54
                                    p_currency_code   =>
                                        c_po_recv.currency_code, --added as per CR#54
                                    p_code_combination_id   =>
                                        c_po_recv.code_combination_id,
                                    p_debit_amount    => l_oh_nonduty_amt,
                                    p_credit_amount   => NULL,
                                    p_batch_name      => g_reverse_batch_name,
                                    p_batch_desc      => g_reverse_batch_name,
                                    p_journal_name    =>
                                           c_po_recv.Shipment_num
                                        || '-'
                                        || c_po_recv.transaction_Id,
                                    p_journal_desc    =>
                                           g_reverse_batch_name
                                        || '-'
                                        || c_po_recv.Shipment_num,
                                    p_line_desc       =>
                                           'OH NONDUTY'
                                        || '-'
                                        || c_po_recv.Shipment_num
                                        || ' '
                                        || c_po_recv.transaction_Id,
                                    p_context         =>
                                        v_reverse_intransit_context,
                                    P_attribute1      =>
                                        c_po_recv.transaction_Id);

                                SELECT segment1, segment2, segment3,
                                       segment4, segment5, segment6,
                                       segment7, segment8
                                  INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                                 v_segment5, v_segment6, v_segment7,
                                                 v_segment8
                                  FROM gl_code_combinations
                                 WHERE code_combination_id =
                                       c_po_recv.code_combination_id;

                                fnd_file.put_line (
                                    fnd_file.output,
                                       RPAD (v_region, 10, ' ')   --CCR0007979
                                    || RPAD (c_po_recv.po_num, 12, ' ')
                                    || RPAD (c_po_recv.Shipment_num, 25, ' ')
                                    || RPAD (c_po_recv.Item_Num, 20, ' ')
                                    || RPAD (c_po_recv.po_unit_price,
                                             17,
                                             ' ')
                                    || RPAD (l_oh_nonduty_amt, 10, ' ')
                                    || RPAD (g_reverse_batch_name, 47, ' ')
                                    || RPAD (
                                              c_po_recv.Shipment_num
                                           || '-'
                                           || c_po_recv.transaction_Id,
                                           30,
                                           ' ')
                                    || RPAD (
                                              'OH NONDUTY'
                                           || '-'
                                           || c_po_recv.Shipment_num
                                           || ' '
                                           || c_po_recv.transaction_Id,
                                           45,
                                           ' ')
                                    || RPAD (
                                              v_segment1
                                           || '.'
                                           || v_segment2
                                           || '.'
                                           || v_segment3
                                           || '.'
                                           || v_segment4
                                           || '.'
                                           || v_segment5
                                           || '.'
                                           || v_segment6
                                           || '.'
                                           || v_segment7
                                           || '.'
                                           || v_segment8,
                                           60,
                                           ' ')
                                    || CHR (13)
                                    || CHR (10));
                            ELSIF c_po_recv.description LIKE 'OVERHEAD%'
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       ' Overhead - Processing Transaction : '
                                    || c_po_recv.transaction_id);

                                --Change as per CR#54 starts
                                --ELEMENTS_IN_DFF - Start
                                IF c_po_recv.unit_overheads_amt IS NOT NULL
                                THEN
                                    l_overheads_cost   :=
                                        c_po_recv.unit_overheads_amt;
                                ELSE
                                    --ELEMENTS_IN_DFF - End
                                    l_overheads_cost   :=
                                        get_amount (
                                            p_cost   => 'OVERHEADS ',
                                            p_organization_id   =>
                                                c_po_recv.organization_id,
                                            p_inventory_item_id   =>
                                                c_po_recv.inventory_item_id,
                                            p_po_header_id   =>
                                                c_po_recv.po_header_id,
                                            p_po_line_id   =>
                                                c_po_recv.po_line_id,
                                            p_po_line_location_id   =>
                                                c_po_recv.po_line_location_id);
                                END IF;

                                l_overheads_amt   :=
                                    ROUND (l_overheads_cost * v_quantity, 2);
                                /* l_overheads_amt :=
                                      (c_po_recv.entered_dr / c_po_recv.quantity_shipped)
                                    * v_quantity;*/
                                --Change as per CR#54 ends
                                insert_into_gl_iface (
                                    p_ledger_id       => c_po_recv.ledger_id,
                                    p_date_created    =>
                                        c_po_recv.transaction_date,
                                    --p_currency_code         => 'USD',--commented as per CR#54
                                    p_currency_code   =>
                                        c_po_recv.currency_code, --added as per CR#54
                                    p_code_combination_id   =>
                                        c_po_recv.code_combination_id,
                                    p_debit_amount    => NULL,
                                    p_credit_amount   => l_overheads_amt,
                                    p_batch_name      => g_reverse_batch_name,
                                    p_batch_desc      => g_reverse_batch_name,
                                    p_journal_name    =>
                                           c_po_recv.Shipment_num
                                        || '-'
                                        || c_po_recv.transaction_Id,
                                    p_journal_desc    =>
                                           g_reverse_batch_name
                                        || '-'
                                        || c_po_recv.Shipment_num,
                                    p_line_desc       =>
                                           'OVERHEADS '
                                        || '-'
                                        || c_po_recv.Shipment_num
                                        || ' '
                                        || c_po_recv.transaction_Id,
                                    p_context         =>
                                        v_reverse_intransit_context,
                                    P_attribute1      =>
                                        c_po_recv.transaction_Id);

                                SELECT segment1, segment2, segment3,
                                       segment4, segment5, segment6,
                                       segment7, segment8
                                  INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                                 v_segment5, v_segment6, v_segment7,
                                                 v_segment8
                                  FROM gl_code_combinations
                                 WHERE code_combination_id =
                                       c_po_recv.code_combination_id;

                                fnd_file.put_line (
                                    fnd_file.output,
                                       RPAD (v_region, 10, ' ')   --CCR0007979
                                    || RPAD (c_po_recv.po_num, 12, ' ')
                                    || RPAD (c_po_recv.Shipment_num, 25, ' ')
                                    || RPAD (c_po_recv.Item_Num, 20, ' ')
                                    || RPAD (c_po_recv.po_unit_price,
                                             17,
                                             ' ')
                                    || RPAD (l_overheads_amt, 10, ' ')
                                    || RPAD (g_reverse_batch_name, 47, ' ')
                                    || RPAD (
                                              c_po_recv.Shipment_num
                                           || '-'
                                           || c_po_recv.transaction_Id,
                                           30,
                                           ' ')
                                    || RPAD (
                                              'OVERHEADS '
                                           || '-'
                                           || c_po_recv.Shipment_num
                                           || ' '
                                           || c_po_recv.transaction_Id,
                                           45,
                                           ' ')
                                    || RPAD (
                                              v_segment1
                                           || '.'
                                           || v_segment2
                                           || '.'
                                           || v_segment3
                                           || '.'
                                           || v_segment4
                                           || '.'
                                           || v_segment5
                                           || '.'
                                           || v_segment6
                                           || '.'
                                           || v_segment7
                                           || '.'
                                           || v_segment8,
                                           60,
                                           ' ')
                                    || CHR (13)
                                    || CHR (10));
                            ELSIF c_po_recv.description LIKE 'Factory Cost%'
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       ' Factory Cost - Processing Transaction : '
                                    || c_po_recv.transaction_id);
                                --Change as per CR#54 starts
                                l_factorycost_cost   :=
                                    get_amount (
                                        p_cost         => 'Factory Cost',
                                        p_organization_id   =>
                                            c_po_recv.organization_id,
                                        p_inventory_item_id   =>
                                            c_po_recv.inventory_item_id,
                                        p_po_header_id   =>
                                            c_po_recv.po_header_id,
                                        p_po_line_id   => c_po_recv.po_line_id,
                                        p_po_line_location_id   =>
                                            c_po_recv.po_line_location_id);

                                l_factorycost_amt   :=
                                    ROUND (l_factorycost_cost * v_quantity,
                                           2);
                                /* l_factorycost_amt :=
                                      (c_po_recv.entered_cr / c_po_recv.quantity_shipped)
                                    * v_quantity;*/
                                --commented as per CR#54
                                --Change as per CR#54 ends


                                insert_into_gl_iface (
                                    p_ledger_id       => c_po_recv.ledger_id,
                                    p_date_created    =>
                                        c_po_recv.transaction_date,
                                    --p_currency_code         => 'USD',--commented as per CR#54
                                    p_currency_code   =>
                                        c_po_recv.currency_code, --added as per CR#54
                                    p_code_combination_id   =>
                                        c_po_recv.code_combination_id,
                                    p_debit_amount    => l_factorycost_amt,
                                    p_credit_amount   => NULL,
                                    p_batch_name      => g_reverse_batch_name,
                                    p_batch_desc      => g_reverse_batch_name,
                                    p_journal_name    =>
                                           c_po_recv.Shipment_num
                                        || '-'
                                        || c_po_recv.transaction_Id,
                                    p_journal_desc    =>
                                           g_reverse_batch_name
                                        || '-'
                                        || c_po_recv.Shipment_num,
                                    p_line_desc       =>
                                           'Factory Cost'
                                        || '-'
                                        || c_po_recv.Shipment_num
                                        || ' '
                                        || c_po_recv.transaction_Id,
                                    p_context         =>
                                        v_reverse_intransit_context,
                                    P_attribute1      =>
                                        c_po_recv.transaction_Id);

                                SELECT segment1, segment2, segment3,
                                       segment4, segment5, segment6,
                                       segment7, segment8
                                  INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                                 v_segment5, v_segment6, v_segment7,
                                                 v_segment8
                                  FROM gl_code_combinations
                                 WHERE code_combination_id =
                                       c_po_recv.code_combination_id;

                                fnd_file.put_line (
                                    fnd_file.output,
                                       RPAD (v_region, 10, ' ')   --CCR0007979
                                    || RPAD (c_po_recv.po_num, 12, ' ')
                                    || RPAD (c_po_recv.Shipment_num, 25, ' ')
                                    || RPAD (c_po_recv.Item_Num, 20, ' ')
                                    || RPAD (c_po_recv.po_unit_price,
                                             17,
                                             ' ')
                                    || RPAD (l_factorycost_amt, 10, ' ')
                                    || RPAD (g_reverse_batch_name, 47, ' ')
                                    || RPAD (
                                              c_po_recv.Shipment_num
                                           || '-'
                                           || c_po_recv.transaction_Id,
                                           30,
                                           ' ')
                                    || RPAD (
                                              'Factory Cost'
                                           || '-'
                                           || c_po_recv.Shipment_num
                                           || ' '
                                           || c_po_recv.transaction_Id,
                                           45,
                                           ' ')
                                    || RPAD (
                                              v_segment1
                                           || '.'
                                           || v_segment2
                                           || '.'
                                           || v_segment3
                                           || '.'
                                           || v_segment4
                                           || '.'
                                           || v_segment5
                                           || '.'
                                           || v_segment6
                                           || '.'
                                           || v_segment7
                                           || '.'
                                           || v_segment8,
                                           60,
                                           ' ')
                                    || CHR (13)
                                    || CHR (10));
                            ELSIF c_po_recv.description LIKE 'In Transit%'
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       ' In Transit - Processing Transaction : '
                                    || c_po_recv.transaction_id);
                                --Change as per CR#54 starts
                                l_intransit_cost   :=
                                    get_amount (
                                        p_cost         => 'In Transit',
                                        p_organization_id   =>
                                            c_po_recv.organization_id,
                                        p_inventory_item_id   =>
                                            c_po_recv.inventory_item_id,
                                        p_po_header_id   =>
                                            c_po_recv.po_header_id,
                                        p_po_line_id   => c_po_recv.po_line_id,
                                        p_po_line_location_id   =>
                                            c_po_recv.po_line_location_id);

                                l_intransit_amt   :=
                                    ROUND (l_intransit_cost * v_quantity, 2);
                                /*l_intransit_amt :=
                                     (c_po_recv.entered_dr / c_po_recv.quantity_shipped)
                                   * v_quantity;*/
                                --commented as per CR#54

                                --Change as per CR#54 ends


                                insert_into_gl_iface (
                                    p_ledger_id       => c_po_recv.ledger_id,
                                    p_date_created    =>
                                        c_po_recv.transaction_date,
                                    --p_currency_code         => 'USD',--commented as per CR#54
                                    p_currency_code   =>
                                        c_po_recv.currency_code, --added as per CR#54
                                    p_code_combination_id   =>
                                        c_po_recv.code_combination_id,
                                    p_debit_amount    => NULL,
                                    p_credit_amount   => l_intransit_amt,
                                    p_batch_name      => g_reverse_batch_name,
                                    p_batch_desc      => g_reverse_batch_name,
                                    p_journal_name    =>
                                           c_po_recv.Shipment_num
                                        || '-'
                                        || c_po_recv.transaction_Id,
                                    p_journal_desc    =>
                                           g_reverse_batch_name
                                        || '-'
                                        || c_po_recv.Shipment_num,
                                    p_line_desc       =>
                                           'In Transit'
                                        || '-'
                                        || c_po_recv.Shipment_num
                                        || ' '
                                        || c_po_recv.transaction_Id,
                                    p_context         =>
                                        v_reverse_intransit_context,
                                    P_attribute1      =>
                                        c_po_recv.transaction_Id);

                                SELECT segment1, segment2, segment3,
                                       segment4, segment5, segment6,
                                       segment7, segment8
                                  INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                                 v_segment5, v_segment6, v_segment7,
                                                 v_segment8
                                  FROM gl_code_combinations
                                 WHERE code_combination_id =
                                       c_po_recv.code_combination_id;

                                fnd_file.put_line (
                                    fnd_file.output,
                                       RPAD (v_region, 10, ' ')   --CCR0007979
                                    || RPAD (c_po_recv.po_num, 12, ' ')
                                    || RPAD (c_po_recv.Shipment_num, 25, ' ')
                                    || RPAD (c_po_recv.Item_Num, 20, ' ')
                                    || RPAD (c_po_recv.po_unit_price,
                                             17,
                                             ' ')
                                    || RPAD (l_intransit_amt, 10, ' ')
                                    || RPAD (g_reverse_batch_name, 47, ' ')
                                    || RPAD (
                                              c_po_recv.Shipment_num
                                           || '-'
                                           || c_po_recv.transaction_Id,
                                           30,
                                           ' ')
                                    || RPAD (
                                              'In Transit'
                                           || '-'
                                           || c_po_recv.Shipment_num
                                           || ' '
                                           || c_po_recv.transaction_Id,
                                           45,
                                           ' ')
                                    || RPAD (
                                              v_segment1
                                           || '.'
                                           || v_segment2
                                           || '.'
                                           || v_segment3
                                           || '.'
                                           || v_segment4
                                           || '.'
                                           || v_segment5
                                           || '.'
                                           || v_segment6
                                           || '.'
                                           || v_segment7
                                           || '.'
                                           || v_segment8,
                                           60,
                                           ' ')
                                    || CHR (13)
                                    || CHR (10));
                            END IF;

                            --Change as per CR#54 starts
                            SELECT COUNT (attribute1)
                              INTO v_count
                              FROM gl_interface
                             WHERE     context = v_reverse_intransit_context
                                   AND attribute1 = c_po_recv.transaction_Id;

                            IF v_count > 0
                            THEN
                                UPDATE APPS.RCV_TRANSACTIONS
                                   --change starts for defect#749
                                   --SET ATTRIBUTE5 = 'Y'
                                   SET ATTRIBUTE3   = 'Y'
                                 --change ends for defect#749
                                 WHERE TRANSACTION_ID =
                                       c_po_recv.TRANSACTION_ID;
                            END IF;

                            --Change as per CR#54 ends
                            l_reversal_count   := l_reversal_count + 1;

                            -- COMMIT_BATCH_SIZE - Start
                            IF l_reversal_count >= g_commit_batch_size
                            --IF l_reversal_count >= 500
                            -- COMMIT_BATCH_SIZE - End
                            THEN
                                COMMIT;
                                l_reversal_count   := 0;
                            END IF;
                        -- EXCEPTION_HANDLE -- Start

                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Unexpected error occurred while processing reversal transaction : '
                                    || SQLERRM);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Errored ASN # : ' || c_po_recv.Shipment_num);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Errored ASN Line id : ' || c_po_recv.shipment_line_id);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Errored Transaction id : ' || c_po_recv.transaction_id);
                        END;
                    -- EXCEPTION_HANDLE -- End

                    END LOOP;

                    COMMIT;

                    fnd_file.put_line (fnd_file.LOG,
                                       'End of  Processing Transactions ');

                    --Change as per CR#54 starts

                    create_cancel_interface (psqlstat, perrproc, p_shipment_number
                                             , l_ou, v_region);   --CCR0007979
                    create_correction_interface (psqlstat, perrproc, p_shipment_number
                                                 , l_ou, v_region); --CCR0007979
                --Change as per CR#54 ends
                END IF;
            --Change as per CR#54 ends

            END LOOP;

            -- Submit the Journal Import
            -------
            BEGIN
                SELECT COUNT (1)
                  INTO l_int_count
                  FROM gl.gl_interface
                 WHERE     user_je_source_name = 'In Transit'
                       AND ledger_id = 2036;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_int_count   := 0;
            END;

            IF l_int_count > 0
            THEN
                v_req_id   :=
                    fnd_request.submit_request (
                        application   => 'SQLGL',
                        program       => 'GLLEZLSRS',
                        description   => NULL,
                        start_time    => SYSDATE,
                        sub_request   => FALSE,
                        argument1     =>
                            fnd_profile.VALUE ('GL_ACCESS_SET_ID'),
                        argument2     => '3',
                        argument3     => 2036,
                        argument4     => NULL,
                        argument5     => 'N',
                        argument6     => 'N',
                        argument7     => 'O');

                COMMIT;

                IF v_req_id = 0
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Request Not Submitted due to ?'
                        || fnd_message.get
                        || '?.');
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Journal Import Program submitted ? Request id :'
                        || v_req_id);
                END IF;

                IF v_req_id > 0
                THEN
                    fnd_file.PUT_LINE (
                        fnd_file.LOG,
                        '   Waiting for the Journal Import Program');

                    LOOP
                        v_request_status   :=
                            fnd_concurrent.wait_for_request (
                                request_id   => v_req_id,
                                INTERVAL     => 60,
                                max_wait     => 0,
                                phase        => v_phase,
                                status       => v_wait_status,
                                dev_phase    => v_dev_phase,
                                dev_status   => v_dev_status,
                                MESSAGE      => v_message);

                        EXIT WHEN    UPPER (v_phase) = 'COMPLETED'
                                  OR UPPER (v_wait_status) IN
                                         ('CANCELLED', 'ERROR', 'TERMINATED');
                    END LOOP;

                    COMMIT;
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           '  Journal Import Program Request Phase'
                        || '-'
                        || v_dev_phase);
                    fnd_file.PUT_LINE (
                        fnd_file.LOG,
                           '  Journal Import Program Request Dev status'
                        || '-'
                        || v_dev_status);

                    IF     UPPER (v_phase) = 'COMPLETED'
                       AND UPPER (v_wait_status) = 'ERROR'
                    THEN
                        fnd_file.PUT_LINE (
                            fnd_file.LOG,
                            'Journal Import prog completed in error. See log for request id');
                        fnd_file.PUT_LINE (fnd_file.LOG, SQLERRM);
                        psqlstat   :=
                            'Journal Import prog completed in error. See log for request id';
                        perrproc   := '1';
                        RETURN;
                    ELSIF     UPPER (v_phase) = 'COMPLETED'
                          AND UPPER (v_wait_status) = 'NORMAL'
                    THEN
                        fnd_file.PUT_LINE (
                            fnd_file.LOG,
                               'Journal Import Import successfully completed for request id: '
                            || v_req_id);
                    ELSE
                        fnd_file.PUT_LINE (
                            fnd_file.LOG,
                            'The Requisition Import Import request failed.Review log for Oracle request id ');
                        fnd_file.PUT_LINE (fnd_file.LOG, SQLERRM);
                        psqlstat   :=
                            'Journal Import prog completed in error. See log for request id';
                        perrproc   := '1';
                        RETURN;
                    END IF;
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK;
                perrproc   := 2;
                psqlstat   := SQLERRM;
                fnd_file.put_line (fnd_file.LOG, 'Exception1: ' || SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            perrproc   := 2;
            psqlstat   := SQLERRM;
            fnd_file.put_line (fnd_file.LOG, 'Exception3: ' || SQLERRM);
    END Create_In_Transit;


    --CCR0006936 - Added for backward compatablity with Concurent request
    PROCEDURE Create_In_Transit (psqlstat OUT VARCHAR2, perrproc OUT VARCHAR2, p_ou IN NUMBER
                                 ,                        --added as per CR#54
                                   p_shipment_number IN VARCHAR2)
    IS
        l_cst_adj_only   VARCHAR2 (10) := 'N';
    BEGIN
        Create_In_Transit (psqlstat, perrproc, p_ou,      --added as per CR#54
                           p_shipment_number, l_cst_adj_only);
    END;

    ---changes as per CR#54 starts

    --New procedure for CCR0006936
    PROCEDURE create_adjustments_interface (
        psqlstat               OUT VARCHAR2,
        perrproc               OUT VARCHAR2,
        p_shipment_number   IN     VARCHAR2,
        p_ou                IN     NUMBER,
        p_region            IN     VARCHAR2)                      --CCR0007979
    AS
        CURSOR c_asn_adj IS
            SELECT pha.org_id, pha.segment1 po_num, pha.po_header_id,
                   pla.po_line_id, rsl.po_line_location_id, rsl.shipment_line_id,
                   rsh.shipment_num, rsl.creation_date, rsl.attribute2 asn_price,
                   rsl.quantity_shipped, rsl.to_organization_id organization_id, rsl.item_id inventory_item_id,
                   pla.unit_price po_unit_price, pla.attribute12 first_sale, gl.chart_of_accounts_id coc_id,
                   gl.ledger_id, gl.currency_code, TO_NUMBER (rsl.ATTRIBUTE6) unit_duty_amt, --Current GL unit duty
                   TO_NUMBER (rsl.ATTRIBUTE11) unit_oh_amt, --Current GL unit OH
                                                            NVL (TO_NUMBER (rsl.attribute12), 0) unit_delta_amt, --Current GL unit delta
                                                                                                                 msib.segment1 item_num
              FROM rcv_shipment_lines rsl, rcv_shipment_headers rsh, po_lines_all pla,
                   po_headers_all pha, po_line_locations_all plla, org_organization_definitions ood,
                   mtl_system_items_b msib, gl_ledgers gl
             WHERE     shipment_line_status_code = 'EXPECTED'
                   AND rsl.source_document_code = 'PO'
                   AND rsl.shipment_header_id = rsh.shipment_header_id
                   AND plla.po_line_id = pla.po_line_id
                   AND pla.po_header_id = pha.po_header_id
                   AND rsl.po_line_location_id = plla.line_location_id
                   AND rsh.asn_type = 'ASN'
                   AND NVL (rsl.attribute5, 'N') = 'Y'
                   AND pla.attribute12 IS NOT NULL
                   AND rsl.attribute2 IS NOT NULL
                   AND rsh.Shipment_num =
                       NVL (p_shipment_number, rsh.Shipment_num)
                   AND ood.organization_id = rsl.TO_ORGANIZATION_ID
                   AND ood.set_of_books_id = gl.ledger_id
                   AND ood.operating_unit = pha.org_id
                   AND rsl.item_id = msib.inventory_item_id
                   AND rsl.to_organization_id = msib.organization_id
                   AND TO_NUMBER (rsl.attribute2) >
                       TO_NUMBER (pla.attribute12) --Is the ASN proce greater than the first_sale
                   AND EXISTS
                           (SELECT *
                              FROM gl_je_lines
                             WHERE     1 = 1
                                   AND context =
                                       'In-Transit Journal ' || p_region --CCR0007979
                                   AND attribute1 = rsl.Shipment_line_Id)
                   AND NOT EXISTS
                           (SELECT NULL
                              FROM rcv_transactions rt
                             WHERE     rt.transaction_type = 'RECEIVE'
                                   AND rt.shipment_line_id =
                                       rsl.shipment_line_id
                                   AND rt.shipment_header_id =
                                       rsh.shipment_header_id)
                   AND pha.org_id = p_ou;


        l_new_unit_duty_amt              NUMBER;
        l_duty_unit_delta                NUMBER;
        l_duty_ccid                      NUMBER;
        l_overheads_ccid                 NUMBER;
        l_duty_diff_amt                  NUMBER;
        v_adjustment_intransit_context   VARCHAR2 (100);

        v_segment1                       NUMBER := 0;
        v_segment2                       NUMBER := 0;
        v_segment3                       NUMBER := 0;
        v_segment4                       NUMBER := 0;
        v_segment5                       NUMBER := 0;
        v_segment6                       NUMBER := 0;
        v_segment7                       NUMBER := 0;
        v_segment8                       NUMBER := 0;
        --START Added as per CCR0007955
        lv_segment1                      VARCHAR2 (25) := NULL;
        lv_segment2                      VARCHAR2 (25) := NULL;
        lv_segment3                      VARCHAR2 (25) := NULL;
        lv_segment4                      VARCHAR2 (25) := NULL;
        lv_segment5                      VARCHAR2 (25) := NULL;
        lv_segment6                      VARCHAR2 (25) := NULL;
        lv_segment7                      VARCHAR2 (25) := NULL;
        lv_segment8                      VARCHAR2 (25) := NULL;
        ln_null_ccid                     NUMBER := 0;
    --END Added as per CCR0007955
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Adjust start');

        v_adjustment_intransit_context   :=
            g_adjustment_intransit_context || ' ' || p_region;    --CCR0007979

        FOR l_adj_rec IN c_asn_adj
        LOOP
            fnd_file.put_line (fnd_file.LOG,
                               'PO Line ID : ' || l_adj_rec.po_line_id);
            fnd_file.put_line (fnd_file.LOG,
                               'RSL ID : ' || l_adj_rec.shipment_line_id);

            --Initial RSL values:
            fnd_file.put_line (fnd_file.LOG, 'RSL starting entries');
            fnd_file.put_line (fnd_file.LOG,
                               'RSL ATTR  6 :' || l_adj_rec.unit_duty_amt); --Current GL unit duty
            fnd_file.put_line (fnd_file.LOG,
                               'RSL ATTR 11 :' || l_adj_rec.unit_oh_amt); --Current GL unit OH
            fnd_file.put_line (fnd_file.LOG,
                               'RSL ATTR 12 :' || l_adj_rec.unit_delta_amt);

            --Get the new per unit duty cost (this will include the first sale value)
            --ELEMENTS_IN_DFF - End
            l_new_unit_duty_amt   :=
                get_amount (
                    p_cost                  => 'DUTY',
                    p_organization_id       => l_adj_rec.organization_id,
                    p_inventory_item_id     => l_adj_rec.inventory_item_id,
                    p_po_header_id          => l_adj_rec.po_header_id,
                    p_po_line_id            => l_adj_rec.po_line_id,
                    p_po_line_location_id   => l_adj_rec.po_line_location_id);

            fnd_file.put_line (
                fnd_file.LOG,
                'New unit duty amount : ' || l_new_unit_duty_amt);

            --Get unit duty delta as currect ASN unit value - new unit value
            l_duty_unit_delta   :=
                l_adj_rec.unit_duty_amt - l_new_unit_duty_amt;



            fnd_file.put_line (fnd_file.LOG,
                               'Unit duty delta : ' || l_duty_unit_delta);
            fnd_file.put_line (
                fnd_file.LOG,
                'Quantity shipped : ' || l_adj_rec.quantity_shipped);

            fnd_file.put_line (
                fnd_file.LOG,
                   'Orig amt : '
                || ROUND (
                       l_adj_rec.unit_duty_amt * l_adj_rec.quantity_shipped,
                       2));
            fnd_file.put_line (
                fnd_file.LOG,
                   'New amt : '
                || ROUND (l_new_unit_duty_amt * l_adj_rec.quantity_shipped,
                          2));


            --Get duty diff amt as unit delta * asn qty
            -- l_duty_diff_amt := round(l_duty_unit_delta * l_adj_rec.quantity_shipped, 2);

            l_duty_diff_amt   :=
                  ROUND (
                      l_adj_rec.unit_duty_amt * l_adj_rec.quantity_shipped,
                      2)
                - ROUND (l_new_unit_duty_amt * l_adj_rec.quantity_shipped, 2);

            fnd_file.put_line (fnd_file.LOG,
                               'GL - Duty diff amount : ' || l_duty_diff_amt);

            l_duty_ccid   :=
                get_ccid (
                    p_segments             => 'DUTY',
                    p_coc_id               => l_adj_rec.coc_id,
                    p_organization_id      => l_adj_rec.organization_id,
                    p_inventory_item_num   => l_adj_rec.inventory_item_id);

            insert_into_gl_iface (
                p_ledger_id             => l_adj_rec.ledger_id,
                p_date_created          => SYSDATE,             --Date to use?
                p_currency_code         => l_adj_rec.currency_code,
                p_code_combination_id   => l_duty_ccid,
                p_debit_amount          => l_duty_diff_amt,
                p_credit_amount         => NULL,
                /*      p_batch_name            => g_adj_batch_name,
                      p_batch_desc            => g_adj_batch_name,
                      p_journal_name          =>    l_adj_rec.shipment_num
                                                 || '-'
                                                 || l_adj_rec.shipment_line_id,
                      p_journal_desc          =>    g_adj_batch_name
                                                 || '-'
                                                 ||l_adj_rec.shipment_num,
                      p_line_desc             =>    'DUTY'
                                                 || '-'
                                                 || l_adj_rec.shipment_num
                                                 || ' '
                                                 || l_adj_rec.shipment_line_id,
                      p_context               => g_adjustment_intransit_context,*/
                p_batch_name            => g_batch_name,
                p_batch_desc            => g_batch_name,
                p_journal_name          =>
                    l_adj_rec.shipment_num || '-' || l_adj_rec.shipment_line_id,
                p_journal_desc          => g_batch_name || '-' || l_adj_rec.shipment_num,
                p_line_desc             =>
                       'DUTY'
                    || '-'
                    || l_adj_rec.shipment_num
                    || ' '
                    || l_adj_rec.shipment_line_id,
                p_context               => v_adjustment_intransit_context, --CCR0007979
                P_attribute1            => l_adj_rec.shipment_line_id);


            SELECT segment1, segment2, segment3,
                   segment4, segment5, segment6,
                   segment7, segment8
              INTO v_segment1, v_segment2, v_segment3, v_segment4,
                             v_segment5, v_segment6, v_segment7,
                             v_segment8
              FROM gl_code_combinations
             WHERE code_combination_id = l_duty_ccid;

            fnd_file.put_line (
                fnd_file.output,
                   RPAD (p_region, 10, ' ')                       --CCR0007979
                || RPAD (l_adj_rec.po_num, 12, ' ')
                || RPAD (l_adj_rec.Shipment_num, 25, ' ')
                || RPAD (l_adj_rec.Item_Num, 20, ' ')
                || RPAD (l_adj_rec.po_unit_price, 17, ' ')
                || RPAD (g_adj_batch_name, 47, ' ')
                || RPAD (
                       l_adj_rec.Shipment_num || '-' || l_adj_rec.shipment_line_id,
                       30,
                       ' ')
                || RPAD (
                          'DUTY'
                       || '-'
                       || l_adj_rec.Shipment_num
                       || ' '
                       || l_adj_rec.shipment_line_id,
                       45,
                       ' ')
                || RPAD (
                          v_segment1
                       || '.'
                       || v_segment2
                       || '.'
                       || v_segment3
                       || '.'
                       || v_segment4
                       || '.'
                       || v_segment5
                       || '.'
                       || v_segment6
                       || '.'
                       || v_segment7
                       || '.'
                       || v_segment8,
                       60,
                       ' ')
                || CHR (13)
                || CHR (10));

            l_overheads_ccid   :=
                get_ccid (
                    p_segments             => 'OVERHEADS ',
                    p_coc_id               => l_adj_rec.coc_id,
                    p_organization_id      => l_adj_rec.organization_id,
                    p_inventory_item_num   => l_adj_rec.inventory_item_id);

            IF l_overheads_ccid IS NULL OR l_overheads_ccid = 0   -- ZERO_CCID
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'failed to obtain In-transit gl account FOR SHIPMENT -'
                    || l_adj_rec.shipment_num);

                --START Added as per CCR0007955
                IF l_adj_rec.unit_duty_amt IS NOT NULL
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'ADJ-OVERHEADS_CCID is NULL or 0, Inserting CCID-Segments into GL Interface for Error Correction -'
                        || l_adj_rec.shipment_num);

                    get_ccid_segments (p_segments => 'OVERHEADS ', p_coc_id => l_adj_rec.coc_id, p_organization_id => l_adj_rec.organization_id, p_inventory_item_num => l_adj_rec.inventory_item_id, p_segment1 => lv_segment1, p_segment2 => lv_segment2, p_segment3 => lv_segment3, p_segment4 => lv_segment4, p_segment5 => lv_segment5, p_segment6 => lv_segment6, p_segment7 => lv_segment7, p_segment8 => lv_segment8
                                       , p_ccid => ln_null_ccid);

                    insert_gl_iface_noccid (
                        p_ledger_id       => l_adj_rec.ledger_id,
                        p_date_created    => SYSDATE,
                        p_currency_code   => l_adj_rec.currency_code, --added as per CR#54
                        --p_code_combination_id   => ln_null_ccid,
                        p_segment1        => lv_segment1,
                        p_segment2        => lv_segment2,
                        p_segment3        => lv_segment3,
                        p_segment4        => lv_segment4,
                        p_segment5        => lv_segment5,
                        p_segment6        => lv_segment6,
                        p_segment7        => lv_segment7,
                        p_segment8        => lv_segment8,
                        p_debit_amount    => NULL,
                        p_credit_amount   => l_duty_diff_amt,
                        p_batch_name      => g_batch_name,
                        p_batch_desc      => g_batch_name,
                        p_journal_name    =>
                            l_adj_rec.shipment_num || '-' || l_adj_rec.shipment_line_id,
                        p_journal_desc    => g_batch_name || '-' || l_adj_rec.shipment_num,
                        p_line_desc       =>
                               'OVERHEADS '
                            || '-'
                            || l_adj_rec.shipment_num
                            || ' '
                            || l_adj_rec.shipment_line_id,
                        p_context         => v_adjustment_intransit_context, --CCR0007979
                        p_attribute1      => l_adj_rec.shipment_line_id);

                    fnd_file.put_line (
                        fnd_file.LOG,
                           ' NULL-CCID Segments > OVERHEADS'
                        || ' \Shipment_lineid > '
                        || l_adj_rec.shipment_line_id
                        || ' \CCID > '
                        || ln_null_ccid
                        || ' \Segments :'
                        || lv_segment1
                        || '.'
                        || lv_segment2
                        || '.'
                        || lv_segment3
                        || '.'
                        || lv_segment4
                        || '.'
                        || lv_segment5
                        || '.'
                        || lv_segment6
                        || '.'
                        || lv_segment7
                        || '.'
                        || lv_segment8);
                END IF;
            --END Added as per CCR0007955
            ELSE
                IF l_adj_rec.unit_duty_amt IS NULL
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'accrual amount is 0.  skipping GL interface insert FOR SHIPMENT -'
                        || l_adj_rec.shipment_num);
                ELSE
                    insert_into_gl_iface (
                        p_ledger_id             => l_adj_rec.ledger_id,
                        p_date_created          => SYSDATE,
                        --p_currency_code         => 'USD',--commented as per CR#54
                        p_currency_code         => l_adj_rec.currency_code, --added as per CR#54
                        p_code_combination_id   => l_overheads_ccid,
                        p_debit_amount          => NULL,
                        p_credit_amount         => l_duty_diff_amt,
                        p_batch_name            => g_batch_name,
                        p_batch_desc            => g_batch_name,
                        p_journal_name          =>
                            l_adj_rec.shipment_num || '-' || l_adj_rec.shipment_line_id,
                        p_journal_desc          =>
                            g_batch_name || '-' || l_adj_rec.shipment_num,
                        p_line_desc             =>
                               'OVERHEADS '
                            || '-'
                            || l_adj_rec.shipment_num
                            || ' '
                            || l_adj_rec.shipment_line_id,
                        p_context               =>
                            v_adjustment_intransit_context,       --CCR0007979
                        P_attribute1            => l_adj_rec.shipment_line_id);

                    SELECT segment1, segment2, segment3,
                           segment4, segment5, segment6,
                           segment7, segment8
                      INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                     v_segment5, v_segment6, v_segment7,
                                     v_segment8
                      FROM gl_code_combinations
                     WHERE code_combination_id = l_overheads_ccid;

                    fnd_file.put_line (
                        fnd_file.output,
                           RPAD (p_region, 10, ' ')               --CCR0007979
                        || RPAD (l_adj_rec.po_num, 12, ' ')
                        || RPAD (l_adj_rec.Shipment_num, 25, ' ')
                        || RPAD (l_adj_rec.Item_Num, 20, ' ')
                        || RPAD (l_adj_rec.po_unit_price, 17, ' ')
                        || RPAD (g_batch_name, 47, ' ')
                        || RPAD (
                               l_adj_rec.shipment_num || '-' || l_adj_rec.shipment_line_id,
                               40,
                               ' ')
                        || RPAD (
                                  'OVERHEADS '
                               || '-'
                               || l_adj_rec.shipment_num
                               || ' '
                               || l_adj_rec.shipment_line_id,
                               50,
                               ' ')
                        || RPAD (
                                  v_segment1
                               || '.'
                               || v_segment2
                               || '.'
                               || v_segment3
                               || '.'
                               || v_segment4
                               || '.'
                               || v_segment5
                               || '.'
                               || v_segment6
                               || '.'
                               || v_segment7
                               || '.'
                               || v_segment8,
                               60,
                               ' ')
                        || CHR (13)
                        || CHR (10));
                END IF;
            END IF;

            --Updated RSL values:
            fnd_file.put_line (fnd_file.LOG, 'RSL updated entries');
            fnd_file.put_line (
                fnd_file.LOG,
                   'RSL ATTR  6 :'
                || TO_CHAR (l_adj_rec.unit_duty_amt - l_duty_unit_delta)); --Current GL unit duty
            fnd_file.put_line (
                fnd_file.LOG,
                   'RSL ATTR 11 :'
                || TO_CHAR (l_adj_rec.unit_oh_amt - l_duty_unit_delta)); --Current GL unit OH
            fnd_file.put_line (
                fnd_file.LOG,
                   'RSL ATTR 12 :'
                || TO_CHAR (l_adj_rec.unit_delta_amt + l_duty_unit_delta));

            fnd_file.put_line (fnd_file.LOG,
                               'RSL ATTR 2 :' || l_adj_rec.first_sale);

            --Update the RSL running totals.
            UPDATE rcv_shipment_lines
               SET attribute2 = l_adj_rec.first_sale, attribute6 = l_adj_rec.unit_duty_amt - l_duty_unit_delta, attribute11 = l_adj_rec.unit_oh_amt - l_duty_unit_delta,
                   attribute12 = l_adj_rec.unit_delta_amt + l_duty_unit_delta
             WHERE shipment_line_id = l_adj_rec.shipment_line_id;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            perrproc   := 2;
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    -- psqlstat := SQLERRM;
    -- fnd_file.put_line (fnd_file.LOG, 'Exception: ' || SQLERRM);
    END;

    --End CCR0006936

    PROCEDURE create_cancel_interface (psqlstat               OUT VARCHAR2,
                                       perrproc               OUT VARCHAR2,
                                       p_shipment_number   IN     VARCHAR2,
                                       p_ou                IN     NUMBER,
                                       p_region            IN     VARCHAR2) --CCR0007979
    AS
        CURSOR c_po_cancel_recvs IS
            SELECT                      --rt.transaction_id AS transaction_id,
                   rsl.shipment_line_id AS shipment_line_id,
                   NVL (
                       (SELECT SUM (rt.quantity)
                          FROM rcv_transactions rt
                         WHERE     1 = 1
                               AND rt.shipment_header_id =
                                   rsh.shipment_header_id
                               AND rt.shipment_line_id = rsl.shipment_line_id
                               AND rt.transaction_type = 'RECEIVE'
                               AND rt.SOURCE_DOCUMENT_CODE = 'PO'),
                       0) AS quantity_received,
                   NVL (rsl.quantity_shipped, 0) AS quantity_shipped,
                   rsh.Shipment_num AS Shipment_num,
                   rsh.creation_date AS asn_creation_date,
                   --rsh.last_update_date as asn_update_date, --added on 02/05/16 -- Commented by Ravi as part of INC0294936
                   rsl.last_update_date AS asn_update_date, --added by Ravi  as part of INC0294936
                   poh.po_header_id AS po_header_id,
                   pol.po_line_id AS po_line_id,
                   rsl.po_line_location_id AS po_line_location_id,
                   ood.organization_id AS organization_id,
                   poh.segment1 AS po_num,
                   pol.unit_price AS po_unit_price,
                   msib.inventory_item_id AS inventory_item_id,
                   msib.segment1 AS Item_Num,
                   gl.code_combination_id AS code_combination_id,
                   gl.entered_dr AS entered_dr,
                   gl.entered_cr AS entered_cr,
                   gl.description AS description,
                   gl.ledger_id AS ledger_id,
                   GLl.CURRENCY_CODE,
                   gll.chart_of_accounts_id,
                   --ELEMENTS_IN_DFF - Start
                   TO_NUMBER (rsl.ATTRIBUTE6) unit_duty_amt,
                   TO_NUMBER (rsl.ATTRIBUTE7) unit_freight_amt,
                   TO_NUMBER (rsl.ATTRIBUTE8) unit_freightdu_amt,
                   TO_NUMBER (rsl.ATTRIBUTE9) unit_ohduty_amt,
                   TO_NUMBER (rsl.ATTRIBUTE10) unit_oh_nonduty_amt,
                   TO_NUMBER (rsl.ATTRIBUTE11) unit_overheads_amt,
                   --CCR0006036
                   --Get adjustment values to use in calculation for cancel GL eneties
                   NVL (
                       (SELECT SUM (entered_cr)
                          FROM gl_je_lines gl1
                         WHERE     gl1.ledger_id = gl.ledger_id
                               AND TO_NUMBER (gl1.attribute1) =
                                   TO_NUMBER (gl.attribute1)
                               AND gl1.code_combination_id =
                                   gl.code_combination_id
                               AND gl1.context =
                                      'Adjustment In-Transit Journal '
                                   || p_region),                  --CCR0007979
                       0) adj_entered_cr,
                   NVL (
                       (SELECT SUM (entered_dr)
                          FROM gl_je_lines gl1
                         WHERE     gl1.ledger_id = gl.ledger_id
                               AND TO_NUMBER (gl1.attribute1) =
                                   TO_NUMBER (gl.attribute1)
                               AND gl1.code_combination_id =
                                   gl.code_combination_id
                               AND gl1.context =
                                      'Adjustment In-Transit Journal '
                                   || p_region),                  --CCR0007979
                       0) adj_entered_dr
              --End CCR0006036
              --ELEMENTS_IN_DFF - End
              FROM                                      --rcv_transactions rt,
                   mtl_system_items_b msib, org_organization_definitions ood, rcv_shipment_headers rsh,
                   rcv_shipment_lines rsl, po_headers_all poh, po_lines_all pol,
                   gl_je_lines gl, gl_ledgers gll
             WHERE     1 = 1
                   AND gl.attribute1 = rsl.shipment_line_id
                   AND NVL (rsl.attribute4, 'N') = 'N'
                   AND gl.ledger_id = ood.set_of_books_id
                   AND gl.ledger_id = gll.ledger_id
                   AND gl.context = 'In-Transit Journal ' || p_region --CCR0007979
                   --AND rt.organization_id = ood.organization_id
                   AND msib.organization_id = ood.organization_id
                   AND ood.operating_unit = poh.org_id
                   -- AND rt.shipment_header_id = rsh.shipment_header_id
                   AND rsl.shipment_header_id = rsh.shipment_header_id
                   AND poh.po_header_id = pol.po_header_id
                   AND pol.PO_LINE_ID = rsl.PO_LINE_ID
                   AND msib.inventory_item_id = rsl.item_id
                   AND msib.ORGANIZATION_ID = rsl.TO_ORGANIZATION_ID
                   AND rsl.shipment_line_status_code = 'CANCELLED'
                   AND rsh.Shipment_num =
                       NVL (p_shipment_number, rsh.Shipment_num)
                   --                AND rt.transaction_type = 'CANCEL'
                   --                AND rt.SOURCE_DOCUMENT_CODE = 'PO'
                   --                AND poh.po_header_id = rt.po_header_id
                   AND poh.org_id = p_ou;

        l_duty_amt                    NUMBER;
        l_duty_cost                   NUMBER;
        l_freight_amt                 NUMBER;
        l_freight_cost                NUMBER;
        l_intransit_amt               NUMBER;
        l_factorycost_amt             NUMBER;
        l_overheads_amt               NUMBER;
        l_oh_nonduty_amt              NUMBER;
        l_ohduty_amt                  NUMBER;
        l_freightdu_amt               NUMBER;
        l_intransit_cost              NUMBER;
        l_factorycost_cost            NUMBER;
        l_overheads_cost              NUMBER;
        l_oh_nonduty_cost             NUMBER;
        l_ohduty_cost                 NUMBER;
        l_freightdu_cost              NUMBER;
        v_count                       NUMBER;
        --      l_duty_ccid            NUMBER;
        --      l_intransit_ccid       NUMBER;
        --      l_overheads_ccid       NUMBER;
        --      l_factorycost_ccid     NUMBER;
        --      l_freightdu_ccid       NUMBER;
        --      l_ohduty_ccid          NUMBER;
        --      l_oh_nonduty_ccid      NUMBER;
        --      l_freight_ccid         NUMBER;
        --  l_amt_to_credit        NUMBER;
        --  l_amt_to_debit         NUMBER;
        --  l_org_id               NUMBER;
        -- l_proc_name            VARCHAR2 (200)
        --                           := lg_package_name || '.insert_into_gl_iface';
        -- l_period_name          gl_periods.period_name%TYPE;
        v_quantity                    NUMBER;
        -- shipped_quantity       NUMBER;
        --received_quantity      NUMBER;
        v_segment1                    NUMBER := 0;
        v_segment2                    NUMBER := 0;
        v_segment3                    NUMBER := 0;
        v_segment4                    NUMBER := 0;
        v_segment5                    NUMBER := 0;
        v_segment6                    NUMBER := 0;
        v_segment7                    NUMBER := 0;
        v_segment8                    NUMBER := 0;
        --l_asn_count            NUMBER := 0;
        l_reversal_count              NUMBER := 0;
        v_reverse_cancelled_context   VARCHAR2 (100);
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'Cancel Interface Begin : '
            || TO_CHAR (SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));

        v_reverse_cancelled_context   :=
            g_reverse_cancelled_context || ' ' || p_region;       --CCR0007979

        FOR l_cancel_rec IN c_po_cancel_recvs
        LOOP
            fnd_file.put_line (
                fnd_file.LOG,
                   'Cancel Interface Loop : '
                || TO_CHAR (SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));

            IF l_cancel_rec.quantity_received > l_cancel_rec.quantity_shipped
            THEN
                v_quantity   := l_cancel_rec.quantity_shipped;
            ELSE
                v_quantity   := l_cancel_rec.quantity_received;
            END IF;


            IF l_cancel_rec.description LIKE 'DUTY%'
            THEN
                -- ELEMENTS_IN_DFF - Start
                IF l_cancel_rec.unit_duty_amt IS NOT NULL
                THEN
                    l_duty_cost   := l_cancel_rec.unit_duty_amt;
                ELSE
                    -- ELEMENTS_IN_DFF - End
                    l_duty_cost   :=
                        get_amount (
                            p_cost           => 'DUTY',
                            p_organization_id   =>
                                l_cancel_rec.organization_id,
                            p_inventory_item_id   =>
                                l_cancel_rec.inventory_item_id,
                            p_po_header_id   => l_cancel_rec.po_header_id,
                            p_po_line_id     => l_cancel_rec.po_line_id,
                            p_po_line_location_id   =>
                                l_cancel_rec.po_line_location_id);
                END IF;

                IF l_duty_cost != 0
                THEN
                    --CCR0006036
                    --Subtract adjusted amount
                    l_duty_amt   :=
                        ROUND (
                              (l_cancel_rec.entered_cr - l_cancel_rec.adj_entered_dr)
                            -        --(l_cancel_rec.entered_cr / l_duty_cost)
                              l_duty_cost * v_quantity,
                            2);
                ELSE
                    l_duty_amt   := 0;
                END IF;

                insert_into_gl_iface (
                    p_ledger_id       => l_cancel_rec.ledger_id,
                    --p_date_created          => l_cancel_rec.asn_creation_date, --commented on 02/05/16
                    p_date_created    => l_cancel_rec.asn_update_date, --added on 02/05/16
                    --p_currency_code         => 'USD',--commented as per CR#54
                    p_currency_code   => l_cancel_rec.currency_code, --added as per CR#54
                    p_code_combination_id   =>
                        l_cancel_rec.code_combination_id,
                    p_debit_amount    => l_duty_amt,
                    p_credit_amount   => NULL,
                    p_batch_name      => g_rev_can_batch_name,
                    p_batch_desc      => g_rev_can_batch_name,
                    p_journal_name    =>
                           l_cancel_rec.Shipment_num
                        || '- Cancel-'
                        || l_cancel_rec.Shipment_line_id,
                    p_journal_desc    =>
                        g_rev_can_batch_name || '-' || l_cancel_rec.Shipment_num,
                    p_line_desc       =>
                           'DUTY'
                        || '-'
                        || l_cancel_rec.Shipment_num
                        || ' '
                        || l_cancel_rec.Shipment_line_id,
                    p_context         => v_reverse_cancelled_context, --CCR0007979
                    P_attribute1      => l_cancel_rec.Shipment_line_id);


                SELECT segment1, segment2, segment3,
                       segment4, segment5, segment6,
                       segment7, segment8
                  INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                 v_segment5, v_segment6, v_segment7,
                                 v_segment8
                  FROM gl_code_combinations
                 WHERE code_combination_id = l_cancel_rec.code_combination_id;

                fnd_file.put_line (
                    fnd_file.output,
                       RPAD (p_region, 10, ' ')                   --CCR0007979
                    || RPAD (l_cancel_rec.po_num, 12, ' ')
                    || RPAD (l_cancel_rec.Shipment_num, 25, ' ')
                    || RPAD (l_cancel_rec.Item_Num, 20, ' ')
                    || RPAD (l_cancel_rec.po_unit_price, 17, ' ')
                    || RPAD (l_duty_amt, 10, ' ')
                    || RPAD (g_rev_can_batch_name, 47, ' ')
                    || RPAD (
                              l_cancel_rec.Shipment_num
                           || '- Cancel-'
                           || l_cancel_rec.Shipment_line_id,
                           40,
                           ' ')
                    || RPAD (
                              'DUTY'
                           || '-'
                           || l_cancel_rec.Shipment_num
                           || ' '
                           || l_cancel_rec.Shipment_line_id,
                           50,
                           ' ')
                    || RPAD (
                              v_segment1
                           || '.'
                           || v_segment2
                           || '.'
                           || v_segment3
                           || '.'
                           || v_segment4
                           || '.'
                           || v_segment5
                           || '.'
                           || v_segment6
                           || '.'
                           || v_segment7
                           || '.'
                           || v_segment8,
                           60,
                           ' ')
                    || CHR (13)
                    || CHR (10));
            ELSIF l_cancel_rec.description LIKE 'FRGT%'
            THEN
                -- ELEMENTS_IN_DFF - Start
                IF l_cancel_rec.unit_freight_amt IS NOT NULL
                THEN
                    l_freight_cost   := l_cancel_rec.unit_freight_amt;
                ELSE
                    -- ELEMENTS_IN_DFF - End
                    l_freight_cost   :=
                        get_amount (
                            p_cost           => 'FREIGHT',
                            p_organization_id   =>
                                l_cancel_rec.organization_id,
                            p_inventory_item_id   =>
                                l_cancel_rec.inventory_item_id,
                            p_po_header_id   => l_cancel_rec.po_header_id,
                            p_po_line_id     => l_cancel_rec.po_line_id,
                            p_po_line_location_id   =>
                                l_cancel_rec.po_line_location_id);
                END IF;

                IF l_freight_cost != 0
                THEN
                    l_freight_amt   :=
                        ROUND (
                              l_cancel_rec.entered_cr
                            - l_freight_cost * v_quantity,
                            2);
                ELSE
                    l_freight_amt   := 0;
                END IF;


                insert_into_gl_iface (
                    p_ledger_id       => l_cancel_rec.ledger_id,
                    --p_date_created          => l_cancel_rec.asn_creation_date, --commented on 02/05/16
                    p_date_created    => l_cancel_rec.asn_update_date, --added on 02/05/16
                    --p_currency_code         => 'USD',--commented as per CR#54
                    p_currency_code   => l_cancel_rec.currency_code, --added as per CR#54
                    p_code_combination_id   =>
                        l_cancel_rec.code_combination_id,
                    p_debit_amount    => l_freight_amt,
                    p_credit_amount   => NULL,
                    p_batch_name      => g_rev_can_batch_name,
                    p_batch_desc      => g_rev_can_batch_name,
                    p_journal_name    =>
                           l_cancel_rec.Shipment_num
                        || '- Cancel-'
                        || l_cancel_rec.Shipment_line_id,
                    p_journal_desc    =>
                        g_rev_can_batch_name || '-' || l_cancel_rec.Shipment_num,
                    p_line_desc       =>
                           'FRGT'
                        || '-'
                        || l_cancel_rec.Shipment_num
                        || ' '
                        || l_cancel_rec.Shipment_line_id,
                    p_context         => v_reverse_cancelled_context, --CCR0007979
                    P_attribute1      => l_cancel_rec.Shipment_line_id);

                SELECT segment1, segment2, segment3,
                       segment4, segment5, segment6,
                       segment7, segment8
                  INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                 v_segment5, v_segment6, v_segment7,
                                 v_segment8
                  FROM gl_code_combinations
                 WHERE code_combination_id = l_cancel_rec.code_combination_id;

                fnd_file.put_line (
                    fnd_file.output,
                       RPAD (p_region, 10, ' ')                   --CCR0007979
                    || RPAD (l_cancel_rec.po_num, 12, ' ')
                    || RPAD (l_cancel_rec.Shipment_num, 25, ' ')
                    || RPAD (l_cancel_rec.Item_Num, 20, ' ')
                    || RPAD (l_cancel_rec.po_unit_price, 17, ' ')
                    || RPAD (l_freight_amt, 10, ' ')
                    || RPAD (g_rev_can_batch_name, 47, ' ')
                    || RPAD (
                              l_cancel_rec.Shipment_num
                           || '- Cancel-'
                           || l_cancel_rec.Shipment_line_id,
                           40,
                           ' ')
                    || RPAD (
                              'FRGT'
                           || '-'
                           || l_cancel_rec.Shipment_num
                           || ' '
                           || l_cancel_rec.Shipment_line_id,
                           50,
                           ' ')
                    || RPAD (
                              v_segment1
                           || '.'
                           || v_segment2
                           || '.'
                           || v_segment3
                           || '.'
                           || v_segment4
                           || '.'
                           || v_segment5
                           || '.'
                           || v_segment6
                           || '.'
                           || v_segment7
                           || '.'
                           || v_segment8,
                           60,
                           ' ')
                    || CHR (13)
                    || CHR (10));
            ELSIF l_cancel_rec.description LIKE 'FREIGHT_DU%'
            THEN
                -- ELEMENTS_IN_DFF - Start
                IF l_cancel_rec.unit_freightdu_amt IS NOT NULL
                THEN
                    l_freightdu_cost   := l_cancel_rec.unit_freightdu_amt;
                ELSE
                    -- ELEMENTS_IN_DFF - End
                    l_freightdu_cost   :=
                        get_amount (
                            p_cost           => 'FREIGHT DU',
                            p_organization_id   =>
                                l_cancel_rec.organization_id,
                            p_inventory_item_id   =>
                                l_cancel_rec.inventory_item_id,
                            p_po_header_id   => l_cancel_rec.po_header_id,
                            p_po_line_id     => l_cancel_rec.po_line_id,
                            p_po_line_location_id   =>
                                l_cancel_rec.po_line_location_id);
                END IF;

                IF l_freightdu_cost != 0
                THEN
                    l_freightdu_amt   :=
                        ROUND (
                              l_cancel_rec.entered_cr
                            - l_freightdu_cost * v_quantity,
                            2);
                ELSE
                    l_freightdu_amt   := 0;
                END IF;

                insert_into_gl_iface (
                    p_ledger_id       => l_cancel_rec.ledger_id,
                    --p_date_created          => l_cancel_rec.asn_creation_date, --commented on 02/05/16
                    p_date_created    => l_cancel_rec.asn_update_date, --added on 02/05/16
                    --p_currency_code         => 'USD',--commented as per CR#54
                    p_currency_code   => l_cancel_rec.currency_code, --added as per CR#54
                    p_code_combination_id   =>
                        l_cancel_rec.code_combination_id,
                    p_debit_amount    => l_freightdu_amt,
                    p_credit_amount   => NULL,
                    p_batch_name      => g_rev_can_batch_name,
                    p_batch_desc      => g_rev_can_batch_name,
                    p_journal_name    =>
                           l_cancel_rec.Shipment_num
                        || '- Cancel-'
                        || l_cancel_rec.Shipment_line_id,
                    p_journal_desc    =>
                        g_rev_can_batch_name || '-' || l_cancel_rec.Shipment_num,
                    p_line_desc       =>
                           'FREIGHT_DU'
                        || '-'
                        || l_cancel_rec.Shipment_num
                        || ' '
                        || l_cancel_rec.Shipment_line_id,
                    p_context         => v_reverse_cancelled_context, --CCR0007979
                    P_attribute1      => l_cancel_rec.Shipment_line_id);

                SELECT segment1, segment2, segment3,
                       segment4, segment5, segment6,
                       segment7, segment8
                  INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                 v_segment5, v_segment6, v_segment7,
                                 v_segment8
                  FROM gl_code_combinations
                 WHERE code_combination_id = l_cancel_rec.code_combination_id;

                fnd_file.put_line (
                    fnd_file.output,
                       RPAD (p_region, 10, ' ')                   --CCR0007979
                    || RPAD (l_cancel_rec.po_num, 12, ' ')
                    || RPAD (l_cancel_rec.Shipment_num, 25, ' ')
                    || RPAD (l_cancel_rec.Item_Num, 20, ' ')
                    || RPAD (l_cancel_rec.po_unit_price, 17, ' ')
                    || RPAD (l_freightdu_amt, 10, ' ')
                    || RPAD (g_rev_can_batch_name, 47, ' ')
                    || RPAD (
                              l_cancel_rec.Shipment_num
                           || '- Cancel-'
                           || l_cancel_rec.Shipment_line_id,
                           40,
                           ' ')
                    || RPAD (
                              'FREIGHT_DU'
                           || '-'
                           || l_cancel_rec.Shipment_num
                           || ' '
                           || l_cancel_rec.Shipment_line_id,
                           50,
                           ' ')
                    || RPAD (
                              v_segment1
                           || '.'
                           || v_segment2
                           || '.'
                           || v_segment3
                           || '.'
                           || v_segment4
                           || '.'
                           || v_segment5
                           || '.'
                           || v_segment6
                           || '.'
                           || v_segment7
                           || '.'
                           || v_segment8,
                           60,
                           ' ')
                    || CHR (13)
                    || CHR (10));
            ELSIF l_cancel_rec.description LIKE 'OH DUTY%'
            THEN
                -- ELEMENTS_IN_DFF - Start
                IF l_cancel_rec.unit_ohduty_amt IS NOT NULL
                THEN
                    l_ohduty_cost   := l_cancel_rec.unit_ohduty_amt;
                ELSE
                    -- ELEMENTS_IN_DFF - End
                    l_ohduty_cost   :=
                        get_amount (
                            p_cost           => 'OH DUTY',
                            p_organization_id   =>
                                l_cancel_rec.organization_id,
                            p_inventory_item_id   =>
                                l_cancel_rec.inventory_item_id,
                            p_po_header_id   => l_cancel_rec.po_header_id,
                            p_po_line_id     => l_cancel_rec.po_line_id,
                            p_po_line_location_id   =>
                                l_cancel_rec.po_line_location_id);
                END IF;

                IF l_ohduty_cost != 0
                THEN
                    l_ohduty_amt   :=
                        ROUND (
                              l_cancel_rec.entered_cr
                            - l_ohduty_cost * v_quantity,
                            2);
                ELSE
                    l_ohduty_amt   := 0;
                END IF;


                insert_into_gl_iface (
                    p_ledger_id       => l_cancel_rec.ledger_id,
                    --p_date_created          => l_cancel_rec.asn_creation_date, --commented on 02/05/16
                    p_date_created    => l_cancel_rec.asn_update_date, --added on 02/05/16
                    --p_currency_code         => 'USD',--commented as per CR#54
                    p_currency_code   => l_cancel_rec.currency_code, --added as per CR#54
                    p_code_combination_id   =>
                        l_cancel_rec.code_combination_id,
                    p_debit_amount    => l_ohduty_amt,
                    p_credit_amount   => NULL,
                    p_batch_name      => g_rev_can_batch_name,
                    p_batch_desc      => g_rev_can_batch_name,
                    p_journal_name    =>
                           l_cancel_rec.Shipment_num
                        || '- Cancel-'
                        || l_cancel_rec.Shipment_line_id,
                    p_journal_desc    =>
                        g_rev_can_batch_name || '-' || l_cancel_rec.Shipment_num,
                    p_line_desc       =>
                           'OH DUTY'
                        || '-'
                        || l_cancel_rec.Shipment_num
                        || ' '
                        || l_cancel_rec.Shipment_line_id,
                    p_context         => v_reverse_cancelled_context, --CCR0007979
                    P_attribute1      => l_cancel_rec.Shipment_line_id);

                SELECT segment1, segment2, segment3,
                       segment4, segment5, segment6,
                       segment7, segment8
                  INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                 v_segment5, v_segment6, v_segment7,
                                 v_segment8
                  FROM gl_code_combinations
                 WHERE code_combination_id = l_cancel_rec.code_combination_id;

                fnd_file.put_line (
                    fnd_file.output,
                       RPAD (p_region, 10, ' ')                   --CCR0007979
                    || RPAD (l_cancel_rec.po_num, 12, ' ')
                    || RPAD (l_cancel_rec.Shipment_num, 25, ' ')
                    || RPAD (l_cancel_rec.Item_Num, 20, ' ')
                    || RPAD (l_cancel_rec.po_unit_price, 17, ' ')
                    || RPAD (l_ohduty_amt, 10, ' ')
                    || RPAD (g_rev_can_batch_name, 47, ' ')
                    || RPAD (
                              l_cancel_rec.Shipment_num
                           || '- Cancel-'
                           || l_cancel_rec.Shipment_line_id,
                           40,
                           ' ')
                    || RPAD (
                              'OH DUTY'
                           || '-'
                           || l_cancel_rec.Shipment_num
                           || ' '
                           || l_cancel_rec.Shipment_line_id,
                           50,
                           ' ')
                    || RPAD (
                              v_segment1
                           || '.'
                           || v_segment2
                           || '.'
                           || v_segment3
                           || '.'
                           || v_segment4
                           || '.'
                           || v_segment5
                           || '.'
                           || v_segment6
                           || '.'
                           || v_segment7
                           || '.'
                           || v_segment8,
                           60,
                           ' ')
                    || CHR (13)
                    || CHR (10));
            ELSIF l_cancel_rec.description LIKE 'OH NONDUTY%'
            THEN
                -- ELEMENTS_IN_DFF - Start
                IF l_cancel_rec.unit_oh_nonduty_amt IS NOT NULL
                THEN
                    l_oh_nonduty_cost   := l_cancel_rec.unit_oh_nonduty_amt;
                ELSE
                    -- ELEMENTS_IN_DFF - End
                    l_oh_nonduty_cost   :=
                        get_amount (
                            p_cost           => 'OH NONDUTY',
                            p_organization_id   =>
                                l_cancel_rec.organization_id,
                            p_inventory_item_id   =>
                                l_cancel_rec.inventory_item_id,
                            p_po_header_id   => l_cancel_rec.po_header_id,
                            p_po_line_id     => l_cancel_rec.po_line_id,
                            p_po_line_location_id   =>
                                l_cancel_rec.po_line_location_id);
                END IF;

                IF l_oh_nonduty_cost != 0
                THEN
                    l_oh_nonduty_amt   :=
                        ROUND (
                              l_cancel_rec.entered_cr
                            - l_oh_nonduty_cost * v_quantity,
                            2);
                ELSE
                    l_oh_nonduty_amt   := 0;
                END IF;

                insert_into_gl_iface (
                    p_ledger_id       => l_cancel_rec.ledger_id,
                    --p_date_created          => l_cancel_rec.asn_creation_date, --commented on 02/05/16
                    p_date_created    => l_cancel_rec.asn_update_date, --added on 02/05/16
                    --p_currency_code         => 'USD',--commented as per CR#54
                    p_currency_code   => l_cancel_rec.currency_code, --added as per CR#54
                    p_code_combination_id   =>
                        l_cancel_rec.code_combination_id,
                    p_debit_amount    => l_oh_nonduty_amt,
                    p_credit_amount   => NULL,
                    p_batch_name      => g_rev_can_batch_name,
                    p_batch_desc      => g_rev_can_batch_name,
                    p_journal_name    =>
                           l_cancel_rec.Shipment_num
                        || '- Cancel-'
                        || l_cancel_rec.Shipment_line_id,
                    p_journal_desc    =>
                        g_rev_can_batch_name || '-' || l_cancel_rec.Shipment_num,
                    p_line_desc       =>
                           'OH NONDUTY'
                        || '-'
                        || l_cancel_rec.Shipment_num
                        || ' '
                        || l_cancel_rec.Shipment_line_id,
                    p_context         => v_reverse_cancelled_context, --CCR0007979
                    P_attribute1      => l_cancel_rec.Shipment_line_id);

                SELECT segment1, segment2, segment3,
                       segment4, segment5, segment6,
                       segment7, segment8
                  INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                 v_segment5, v_segment6, v_segment7,
                                 v_segment8
                  FROM gl_code_combinations
                 WHERE code_combination_id = l_cancel_rec.code_combination_id;

                fnd_file.put_line (
                    fnd_file.output,
                       RPAD (p_region, 10, ' ')                   --CCR0007979
                    || RPAD (l_cancel_rec.po_num, 12, ' ')
                    || RPAD (l_cancel_rec.Shipment_num, 25, ' ')
                    || RPAD (l_cancel_rec.Item_Num, 20, ' ')
                    || RPAD (l_cancel_rec.po_unit_price, 17, ' ')
                    || RPAD (l_oh_nonduty_amt, 10, ' ')
                    || RPAD (g_rev_can_batch_name, 47, ' ')
                    || RPAD (
                              l_cancel_rec.Shipment_num
                           || '- Cancel-'
                           || l_cancel_rec.Shipment_line_id,
                           40,
                           ' ')
                    || RPAD (
                              'OH NONDUTY'
                           || '-'
                           || l_cancel_rec.Shipment_num
                           || ' '
                           || l_cancel_rec.Shipment_line_id,
                           50,
                           ' ')
                    || RPAD (
                              v_segment1
                           || '.'
                           || v_segment2
                           || '.'
                           || v_segment3
                           || '.'
                           || v_segment4
                           || '.'
                           || v_segment5
                           || '.'
                           || v_segment6
                           || '.'
                           || v_segment7
                           || '.'
                           || v_segment8,
                           60,
                           ' ')
                    || CHR (13)
                    || CHR (10));
            ELSIF l_cancel_rec.description LIKE 'OVERHEAD%'
            THEN
                -- ELEMENTS_IN_DFF - Start
                IF l_cancel_rec.unit_overheads_amt IS NOT NULL
                THEN
                    l_overheads_cost   := l_cancel_rec.unit_overheads_amt;
                ELSE
                    -- ELEMENTS_IN_DFF - End
                    l_overheads_cost   :=
                        get_amount (
                            p_cost           => 'OVERHEADS ',
                            p_organization_id   =>
                                l_cancel_rec.organization_id,
                            p_inventory_item_id   =>
                                l_cancel_rec.inventory_item_id,
                            p_po_header_id   => l_cancel_rec.po_header_id,
                            p_po_line_id     => l_cancel_rec.po_line_id,
                            p_po_line_location_id   =>
                                l_cancel_rec.po_line_location_id);
                END IF;

                IF l_overheads_cost != 0
                THEN
                    --CCR0006036
                    --Subtract adjusted amount
                    l_overheads_amt   :=
                        ROUND (
                              l_cancel_rec.entered_dr
                            - l_cancel_rec.adj_entered_cr
                            - l_overheads_cost * v_quantity,
                            2);
                --End CCR0006036
                ELSE
                    l_overheads_amt   := 0;
                END IF;

                insert_into_gl_iface (
                    p_ledger_id       => l_cancel_rec.ledger_id,
                    --p_date_created          => l_cancel_rec.asn_creation_date, --commented on 02/05/16
                    p_date_created    => l_cancel_rec.asn_update_date, --added on 02/05/16
                    --p_currency_code         => 'USD',--commented as per CR#54
                    p_currency_code   => l_cancel_rec.currency_code, --added as per CR#54
                    p_code_combination_id   =>
                        l_cancel_rec.code_combination_id,
                    p_debit_amount    => NULL,
                    p_credit_amount   => l_overheads_amt,
                    p_batch_name      => g_rev_can_batch_name,
                    p_batch_desc      => g_rev_can_batch_name,
                    p_journal_name    =>
                           l_cancel_rec.Shipment_num
                        || '- Cancel-'
                        || l_cancel_rec.Shipment_line_id,
                    p_journal_desc    =>
                        g_rev_can_batch_name || '-' || l_cancel_rec.Shipment_num,
                    p_line_desc       =>
                           'OVERHEADS '
                        || '-'
                        || l_cancel_rec.Shipment_num
                        || ' '
                        || l_cancel_rec.Shipment_line_id,
                    p_context         => v_reverse_cancelled_context, --CCR0007979
                    P_attribute1      => l_cancel_rec.Shipment_line_id);

                SELECT segment1, segment2, segment3,
                       segment4, segment5, segment6,
                       segment7, segment8
                  INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                 v_segment5, v_segment6, v_segment7,
                                 v_segment8
                  FROM gl_code_combinations
                 WHERE code_combination_id = l_cancel_rec.code_combination_id;

                fnd_file.put_line (
                    fnd_file.output,
                       RPAD (p_region, 10, ' ')                   --CCR0007979
                    || RPAD (l_cancel_rec.po_num, 12, ' ')
                    || RPAD (l_cancel_rec.Shipment_num, 25, ' ')
                    || RPAD (l_cancel_rec.Item_Num, 20, ' ')
                    || RPAD (l_cancel_rec.po_unit_price, 17, ' ')
                    || RPAD (l_overheads_amt, 10, ' ')
                    || RPAD (g_rev_can_batch_name, 47, ' ')
                    || RPAD (
                              l_cancel_rec.Shipment_num
                           || '- Cancel-'
                           || l_cancel_rec.Shipment_line_id,
                           40,
                           ' ')
                    || RPAD (
                              'OVERHEADS '
                           || '-'
                           || l_cancel_rec.Shipment_num
                           || ' '
                           || l_cancel_rec.Shipment_line_id,
                           50,
                           ' ')
                    || RPAD (
                              v_segment1
                           || '.'
                           || v_segment2
                           || '.'
                           || v_segment3
                           || '.'
                           || v_segment4
                           || '.'
                           || v_segment5
                           || '.'
                           || v_segment6
                           || '.'
                           || v_segment7
                           || '.'
                           || v_segment8,
                           60,
                           ' ')
                    || CHR (13)
                    || CHR (10));
            ELSIF l_cancel_rec.description LIKE 'Factory Cost%'
            THEN
                l_factorycost_cost   :=
                    get_amount (
                        p_cost              => 'Factory Cost',
                        p_organization_id   => l_cancel_rec.organization_id,
                        p_inventory_item_id   =>
                            l_cancel_rec.inventory_item_id,
                        p_po_header_id      => l_cancel_rec.po_header_id,
                        p_po_line_id        => l_cancel_rec.po_line_id,
                        p_po_line_location_id   =>
                            l_cancel_rec.po_line_location_id);


                IF l_factorycost_cost != 0
                THEN
                    l_factorycost_amt   :=
                        ROUND (
                              l_cancel_rec.entered_cr
                            - l_factorycost_cost * v_quantity,
                            2);
                ELSE
                    l_factorycost_amt   := 0;
                END IF;

                insert_into_gl_iface (
                    p_ledger_id       => l_cancel_rec.ledger_id,
                    --p_date_created          => l_cancel_rec.asn_creation_date, --commented on 02/05/16
                    p_date_created    => l_cancel_rec.asn_update_date, --added on 02/05/16
                    --p_currency_code         => 'USD',--commented as per CR#54
                    p_currency_code   => l_cancel_rec.currency_code, --added as per CR#54
                    p_code_combination_id   =>
                        l_cancel_rec.code_combination_id,
                    p_debit_amount    => l_factorycost_amt,
                    p_credit_amount   => NULL,
                    p_batch_name      => g_rev_can_batch_name,
                    p_batch_desc      => g_rev_can_batch_name,
                    p_journal_name    =>
                           l_cancel_rec.Shipment_num
                        || '- Cancel-'
                        || l_cancel_rec.Shipment_line_id,
                    p_journal_desc    =>
                        g_rev_can_batch_name || '-' || l_cancel_rec.Shipment_num,
                    p_line_desc       =>
                           'Factory Cost'
                        || '-'
                        || l_cancel_rec.Shipment_num
                        || ' '
                        || l_cancel_rec.Shipment_line_id,
                    p_context         => v_reverse_cancelled_context, --CCR0007979
                    P_attribute1      => l_cancel_rec.Shipment_line_id);

                SELECT segment1, segment2, segment3,
                       segment4, segment5, segment6,
                       segment7, segment8
                  INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                 v_segment5, v_segment6, v_segment7,
                                 v_segment8
                  FROM gl_code_combinations
                 WHERE code_combination_id = l_cancel_rec.code_combination_id;

                fnd_file.put_line (
                    fnd_file.output,
                       RPAD (p_region, 10, ' ')                   --CCR0007979
                    || RPAD (l_cancel_rec.po_num, 12, ' ')
                    || RPAD (l_cancel_rec.Shipment_num, 25, ' ')
                    || RPAD (l_cancel_rec.Item_Num, 20, ' ')
                    || RPAD (l_cancel_rec.po_unit_price, 17, ' ')
                    || RPAD (l_factorycost_amt, 10, ' ')
                    || RPAD (g_rev_can_batch_name, 47, ' ')
                    || RPAD (
                              l_cancel_rec.Shipment_num
                           || '- Cancel-'
                           || l_cancel_rec.Shipment_line_id,
                           40,
                           ' ')
                    || RPAD (
                              'Factory Cost'
                           || '-'
                           || l_cancel_rec.Shipment_num
                           || ' '
                           || l_cancel_rec.Shipment_line_id,
                           50,
                           ' ')
                    || RPAD (
                              v_segment1
                           || '.'
                           || v_segment2
                           || '.'
                           || v_segment3
                           || '.'
                           || v_segment4
                           || '.'
                           || v_segment5
                           || '.'
                           || v_segment6
                           || '.'
                           || v_segment7
                           || '.'
                           || v_segment8,
                           60,
                           ' ')
                    || CHR (13)
                    || CHR (10));
            ELSIF l_cancel_rec.description LIKE 'In Transit%'
            THEN
                l_intransit_cost   :=
                    get_amount (
                        p_cost              => 'In Transit',
                        p_organization_id   => l_cancel_rec.organization_id,
                        p_inventory_item_id   =>
                            l_cancel_rec.inventory_item_id,
                        p_po_header_id      => l_cancel_rec.po_header_id,
                        p_po_line_id        => l_cancel_rec.po_line_id,
                        p_po_line_location_id   =>
                            l_cancel_rec.po_line_location_id);

                IF l_intransit_cost != 0
                THEN
                    l_intransit_amt   :=
                        ROUND (
                              l_cancel_rec.entered_dr
                            - l_intransit_cost * v_quantity,
                            2);
                ELSE
                    l_intransit_amt   := 0;
                END IF;


                insert_into_gl_iface (
                    p_ledger_id       => l_cancel_rec.ledger_id,
                    --p_date_created          => l_cancel_rec.asn_creation_date, --commented on 02/05/16
                    p_date_created    => l_cancel_rec.asn_update_date, --added on 02/05/16
                    --p_currency_code         => 'USD',--commented as per CR#54
                    p_currency_code   => l_cancel_rec.currency_code, --added as per CR#54
                    p_code_combination_id   =>
                        l_cancel_rec.code_combination_id,
                    p_debit_amount    => NULL,
                    p_credit_amount   => l_intransit_amt,
                    p_batch_name      => g_rev_can_batch_name,
                    p_batch_desc      => g_rev_can_batch_name,
                    p_journal_name    =>
                           l_cancel_rec.Shipment_num
                        || '- Cancel-'
                        || l_cancel_rec.Shipment_line_id,
                    p_journal_desc    =>
                        g_rev_can_batch_name || '-' || l_cancel_rec.Shipment_num,
                    p_line_desc       =>
                           'In Transit'
                        || '-'
                        || l_cancel_rec.Shipment_num
                        || ' '
                        || l_cancel_rec.Shipment_line_id,
                    p_context         => v_reverse_cancelled_context, --CCR0007979
                    P_attribute1      => l_cancel_rec.Shipment_line_id);

                SELECT segment1, segment2, segment3,
                       segment4, segment5, segment6,
                       segment7, segment8
                  INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                 v_segment5, v_segment6, v_segment7,
                                 v_segment8
                  FROM gl_code_combinations
                 WHERE code_combination_id = l_cancel_rec.code_combination_id;

                fnd_file.put_line (
                    fnd_file.output,
                       RPAD (p_region, 10, ' ')                   --CCR0007979
                    || RPAD (l_cancel_rec.po_num, 12, ' ')
                    || RPAD (l_cancel_rec.Shipment_num, 25, ' ')
                    || RPAD (l_cancel_rec.Item_Num, 20, ' ')
                    || RPAD (l_cancel_rec.po_unit_price, 17, ' ')
                    || RPAD (l_intransit_amt, 10, ' ')
                    || RPAD (g_rev_can_batch_name, 47, ' ')
                    || RPAD (
                              l_cancel_rec.Shipment_num
                           || '- Cancel-'
                           || l_cancel_rec.Shipment_line_id,
                           40,
                           ' ')
                    || RPAD (
                              'In Transit'
                           || '-'
                           || l_cancel_rec.Shipment_num
                           || ' '
                           || l_cancel_rec.Shipment_line_id,
                           50,
                           ' ')
                    || RPAD (
                              v_segment1
                           || '.'
                           || v_segment2
                           || '.'
                           || v_segment3
                           || '.'
                           || v_segment4
                           || '.'
                           || v_segment5
                           || '.'
                           || v_segment6
                           || '.'
                           || v_segment7
                           || '.'
                           || v_segment8,
                           60,
                           ' ')
                    || CHR (13)
                    || CHR (10));
            END IF;

            SELECT COUNT (attribute1)
              INTO v_count
              FROM gl_interface
             WHERE     context = v_reverse_cancelled_context      --CCR0007979
                   AND attribute1 = l_cancel_rec.Shipment_line_id;

            IF v_count > 0
            THEN
                UPDATE APPS.RCV_SHIPMENT_LINES
                   SET ATTRIBUTE4   = 'Y'
                 WHERE SHIPMENT_LINE_ID = l_cancel_rec.shipment_line_id;
            END IF;


            l_reversal_count   := l_reversal_count + 1;

            -- COMMIT_BATCH_SIZE - Start
            IF l_reversal_count >= g_commit_batch_size
            --IF l_reversal_count >= 500
            -- COMMIT_BATCH_SIZE - End
            THEN
                COMMIT;
                l_reversal_count   := 0;
            END IF;
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
               'Cancel Interface End : '
            || TO_CHAR (SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            perrproc   := 2;
            psqlstat   := SQLERRM;
            fnd_file.put_line (fnd_file.LOG, 'Exception2: ' || SQLERRM);
    END create_cancel_interface;

    PROCEDURE create_correction_interface (
        psqlstat               OUT VARCHAR2,
        perrproc               OUT VARCHAR2,
        p_shipment_number   IN     VARCHAR2,
        p_ou                IN     NUMBER,
        p_region            IN     VARCHAR2)                      --CCR0007979
    AS
        CURSOR c_po_correct_recvs IS
            SELECT                     -- rt.transaction_id AS transaction_id,
                   rsl.shipment_line_id
                       AS shipment_line_id,
                   --rsl.quantity_received AS quantity_received,
                   NVL (
                       (SELECT SUM (rt.quantity)
                          FROM rcv_transactions rt
                         WHERE     1 = 1
                               AND rt.shipment_header_id =
                                   rsh.shipment_header_id
                               AND rt.shipment_line_id = rsl.shipment_line_id
                               AND rt.transaction_type = 'RECEIVE'
                               AND rt.SOURCE_DOCUMENT_CODE = 'PO'),
                       0)
                       AS quantity_received,
                   NVL (rsl.quantity_shipped, 0)
                       AS quantity_shipped,
                   rsh.Shipment_num
                       AS Shipment_num,
                   rsh.creation_date
                       AS asn_creation_date,
                   (SELECT SUM (rt.quantity)
                      FROM rcv_transactions rt
                     WHERE     1 = 1
                           AND rt.shipment_header_id = rsh.shipment_header_id
                           AND rt.shipment_line_id = rsl.shipment_line_id
                           AND rt.transaction_type = 'CORRECT'
                           AND destination_type_code = 'RECEIVING'
                           AND rt.SOURCE_DOCUMENT_CODE = 'PO')
                       AS Transaction_quantity,
                   (SELECT MAX (rt.Transaction_date)
                      FROM rcv_transactions rt
                     WHERE     1 = 1
                           AND rt.shipment_header_id = rsh.shipment_header_id
                           AND rt.shipment_line_id = rsl.shipment_line_id
                           AND rt.transaction_type = 'CORRECT'
                           AND destination_type_code = 'RECEIVING'
                           AND rt.SOURCE_DOCUMENT_CODE = 'PO')
                       AS Transaction_date,
                   poh.po_header_id
                       AS po_header_id,
                   pol.po_line_id
                       AS po_line_id,
                   rsl.po_line_location_id
                       AS po_line_location_id,
                   ood.organization_id
                       AS organization_id,
                   poh.segment1
                       AS po_num,
                   pol.unit_price
                       AS po_unit_price,
                   msib.inventory_item_id
                       AS inventory_item_id,
                   msib.segment1
                       AS Item_Num,
                   (SELECT SUM (gjl.entered_dr)
                      FROM gl_je_lines gjl
                     WHERE     gjl.attribute1 = rsl.shipment_line_id
                           --START Added as per CCR0007955
                           --AND gjl.ledger_id = gl.ledger_id
                           AND gjl.ledger_id = ood.set_of_books_id
                           /*     AND gjl.ledger_id =
                                       (SELECT ledger_id
                                          FROM gl_ledgers
                                         WHERE name = 'Deckers US Primary')    -- 2036*/
                           --END Added as per CCR0007955
                           AND gjl.context =
                               'Correct In-Transit Journal ' || p_region --CCR0007979
                           AND gjl.description = gl.description)
                       AS reversed_dr,
                   (SELECT SUM (gjl.entered_cr)
                      FROM gl_je_lines gjl
                     WHERE     gjl.attribute1 = rsl.shipment_line_id
                           --START Added as per CCR0007955
                           --AND gjl.ledger_id = gl.ledger_id
                           AND gjl.ledger_id = ood.set_of_books_id
                           /*  AND gjl.ledger_id =
                                    (SELECT ledger_id
                                       FROM gl_ledgers
                                      WHERE name = 'Deckers US Primary')    -- 2036*/
                           --END Added as per CCR0007955
                           AND gjl.context =
                               'Correct In-Transit Journal ' || p_region --CCR0007979
                           AND gjl.description = gl.description)
                       AS reversed_cr,
                   gl.code_combination_id
                       AS code_combination_id,
                   gl.entered_dr
                       AS entered_dr,
                   gl.entered_cr
                       AS entered_cr,
                   gl.description
                       AS description,
                   gl.ledger_id
                       AS ledger_id,
                   GLl.CURRENCY_CODE,
                   gll.chart_of_accounts_id,
                   -- ELEMENTS_IN_DFF - Start
                   TO_NUMBER (rsl.ATTRIBUTE6)
                       unit_duty_amt,
                   TO_NUMBER (rsl.ATTRIBUTE7)
                       unit_freight_amt,
                   TO_NUMBER (rsl.ATTRIBUTE8)
                       unit_freightdu_amt,
                   TO_NUMBER (rsl.ATTRIBUTE9)
                       unit_ohduty_amt,
                   TO_NUMBER (rsl.ATTRIBUTE10)
                       unit_oh_nonduty_amt,
                   TO_NUMBER (rsl.ATTRIBUTE11)
                       unit_overheads_amt
              -- ELEMENTS_IN_DFF - End
              FROM                                      --rcv_transactions rt,
                   mtl_system_items_b msib, org_organization_definitions ood, rcv_shipment_headers rsh,
                   rcv_shipment_lines rsl, po_headers_all poh, po_lines_all pol,
                   gl_je_lines gl, gl_ledgers gll
             WHERE     1 = 1
                   AND gl.attribute1 = rsl.shipment_line_id
                   --and nvl(rsl.attribute4,'N')= 'N'
                   AND gl.ledger_id = ood.set_of_books_id
                   AND gl.ledger_id = gll.ledger_id
                   AND gl.context = 'In-Transit Journal ' || p_region --CCR0007979
                   --AND rt.organization_id = ood.organization_id
                   AND msib.organization_id = ood.organization_id
                   AND ood.operating_unit = poh.org_id
                   --                AND rt.shipment_header_id = rsh.shipment_header_id
                   --                AND rt.shipment_line_id = rsl.shipment_line_id
                   AND rsl.shipment_header_id = rsh.shipment_header_id
                   AND rsh.Shipment_num =
                       NVL (p_shipment_number, rsh.Shipment_num)
                   AND poh.po_header_id = pol.po_header_id
                   AND pol.PO_LINE_ID = rsl.PO_LINE_ID
                   AND msib.inventory_item_id = rsl.item_id
                   AND msib.ORGANIZATION_ID = rsl.TO_ORGANIZATION_ID
                   -- AND rsl.shipment_line_status_code = 'RECEIVE'
                   AND EXISTS
                           (SELECT 1
                              FROM rcv_transactions rt1
                             WHERE     rt1.transaction_type = 'CORRECT'
                                   --change starts as per defect#749
                                   --AND NVL (rt1.attribute3, 'N') = 'N'
                                   AND rt1.comments IS NULL
                                   --change ends as per defect#749
                                   AND rt1.destination_type_code =
                                       'RECEIVING'
                                   AND rsl.shipment_line_id =
                                       rt1.shipment_line_id)
                   --                AND rt.SOURCE_DOCUMENT_CODE = 'PO'
                   --              AND poh.po_header_id = rt.po_header_id
                   AND poh.org_id = p_ou;

        l_duty_amt                    NUMBER;
        l_freight_amt                 NUMBER;
        l_intransit_amt               NUMBER;
        l_factorycost_amt             NUMBER;
        l_overheads_amt               NUMBER;
        l_oh_nonduty_amt              NUMBER;
        l_ohduty_amt                  NUMBER;
        l_freightdu_amt               NUMBER;
        l_duty_cost                   NUMBER;
        l_freight_cost                NUMBER;
        v_count                       NUMBER;
        l_intransit_cost              NUMBER;
        l_factorycost_cost            NUMBER;
        l_overheads_cost              NUMBER;
        l_oh_nonduty_cost             NUMBER;
        l_ohduty_cost                 NUMBER;
        l_freightdu_cost              NUMBER;
        --      l_duty_ccid            NUMBER;
        --      l_intransit_ccid       NUMBER;
        --      l_overheads_ccid       NUMBER;
        --      l_factorycost_ccid     NUMBER;
        --      l_freightdu_ccid       NUMBER;
        --      l_ohduty_ccid          NUMBER;
        --      l_oh_nonduty_ccid      NUMBER;
        --      l_freight_ccid         NUMBER;
        --  l_amt_to_credit        NUMBER;
        --  l_amt_to_debit         NUMBER;
        --  l_org_id               NUMBER;
        -- l_proc_name            VARCHAR2 (200)
        --                           := lg_package_name || '.insert_into_gl_iface';
        -- l_period_name          gl_periods.period_name%TYPE;
        v_quantity                    NUMBER;
        -- shipped_quantity       NUMBER;
        --received_quantity      NUMBER;
        v_segment1                    NUMBER := 0;
        v_segment2                    NUMBER := 0;
        v_segment3                    NUMBER := 0;
        v_segment4                    NUMBER := 0;
        v_segment5                    NUMBER := 0;
        v_segment6                    NUMBER := 0;
        v_segment7                    NUMBER := 0;
        v_segment8                    NUMBER := 0;
        --l_asn_count            NUMBER := 0;
        l_reversal_count              NUMBER := 0;
        v_reverse_corrected_context   VARCHAR2 (100);
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'Correction Interface Begin : '
            || TO_CHAR (SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));

        v_reverse_corrected_context   :=
            g_reverse_corrected_context || ' ' || p_region;       --CCR0007979

        FOR l_correct_rec IN c_po_correct_recvs
        LOOP
            fnd_file.put_line (
                fnd_file.LOG,
                   'Correction Interface loop : '
                || TO_CHAR (SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));

            IF l_correct_rec.quantity_received >
               l_correct_rec.quantity_shipped
            THEN
                v_quantity   :=
                    LEAST (
                          l_correct_rec.Transaction_quantity
                        + (l_correct_rec.quantity_received - l_correct_rec.quantity_shipped),
                        0);
            ELSE
                v_quantity   := l_correct_rec.Transaction_quantity;
            END IF;

            /*

             IF l_correct_rec.quantity_received > l_correct_rec.quantity_shipped
             THEN
                v_quantity :=
                     l_correct_rec.quantity_received
                   - l_correct_rec.quantity_shipped
                   + l_correct_rec.Transaction_quantity;
             ELSIF l_correct_rec.quantity_received =
                      l_correct_rec.quantity_shipped
             THEN
                v_quantity := l_correct_rec.Transaction_quantity;
             ELSE
                --CCR0006036
                --When correcting out qty make sure over receipts are not corrected out as well
                v_quantity :=
                   LEAST (
                        l_correct_rec.Transaction_quantity
                      + (  l_correct_rec.quantity_received
                         - l_correct_rec.quantity_shipped),
                      0);
              v_quantity :=
                 GREATEST (
                    l_correct_rec.Transaction_quantity,
                      l_correct_rec.quantity_received
                    - l_correct_rec.quantity_shipped);
            --End CCR0006036
            END IF;*/

            IF v_quantity < 0
            THEN
                IF l_correct_rec.description LIKE 'DUTY%'
                THEN
                    -- ELEMENTS_IN_DFF - Start
                    IF l_correct_rec.unit_duty_amt IS NOT NULL
                    THEN
                        l_duty_cost   := l_correct_rec.unit_duty_amt;
                    ELSE
                        -- ELEMENTS_IN_DFF - End
                        l_duty_cost   :=
                            get_amount (
                                p_cost           => 'DUTY',
                                p_organization_id   =>
                                    l_correct_rec.organization_id,
                                p_inventory_item_id   =>
                                    l_correct_rec.inventory_item_id,
                                p_po_header_id   => l_correct_rec.po_header_id,
                                p_po_line_id     => l_correct_rec.po_line_id,
                                p_po_line_location_id   =>
                                    l_correct_rec.po_line_location_id);
                    END IF;

                    IF l_duty_cost != 0
                    THEN
                        l_duty_amt   :=
                            ROUND (
                                  l_duty_cost * ABS (v_quantity)
                                - NVL (l_correct_rec.reversed_Cr, 0),
                                2);
                    ELSE
                        l_duty_amt   := 0;
                    END IF;

                    insert_into_gl_iface (
                        p_ledger_id       => l_correct_rec.ledger_id,
                        --p_date_created          => l_correct_rec.asn_creation_date,--commented on 02/05/16
                        p_date_created    => l_correct_rec.Transaction_date, --added on 02/05/16
                        --p_currency_code         => 'USD',--commented as per CR#54
                        p_currency_code   => l_correct_rec.currency_code, --added as per CR#54
                        p_code_combination_id   =>
                            l_correct_rec.code_combination_id,
                        p_debit_amount    => NULL,
                        p_credit_amount   => l_duty_amt,
                        p_batch_name      => g_rev_cor_batch_name,
                        p_batch_desc      => g_rev_cor_batch_name,
                        p_journal_name    =>
                               l_correct_rec.Shipment_num
                            || '- Correct-'
                            || l_correct_rec.Shipment_line_id,
                        p_journal_desc    =>
                            g_rev_cor_batch_name || '-' || l_correct_rec.Shipment_num,
                        p_line_desc       =>
                               'DUTY'
                            || '-'
                            || l_correct_rec.Shipment_num
                            || ' '
                            || l_correct_rec.Shipment_line_id,
                        p_context         => v_reverse_corrected_context,
                        P_attribute1      => l_correct_rec.Shipment_line_id);


                    SELECT segment1, segment2, segment3,
                           segment4, segment5, segment6,
                           segment7, segment8
                      INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                     v_segment5, v_segment6, v_segment7,
                                     v_segment8
                      FROM gl_code_combinations
                     WHERE code_combination_id =
                           l_correct_rec.code_combination_id;

                    fnd_file.put_line (
                        fnd_file.output,
                           RPAD (p_region, 10, ' ')               --CCR0007979
                        || RPAD (l_correct_rec.po_num, 12, ' ')
                        || RPAD (l_correct_rec.Shipment_num, 25, ' ')
                        || RPAD (l_correct_rec.Item_Num, 20, ' ')
                        || RPAD (l_correct_rec.po_unit_price, 17, ' ')
                        || RPAD (l_duty_amt, 10, ' ')
                        || RPAD (g_rev_cor_batch_name, 47, ' ')
                        || RPAD (
                                  l_correct_rec.Shipment_num
                               || '- Correct-'
                               || l_correct_rec.Shipment_line_id,
                               40,
                               ' ')
                        || RPAD (
                                  'DUTY'
                               || '-'
                               || l_correct_rec.Shipment_num
                               || ' '
                               || l_correct_rec.Shipment_line_id,
                               50,
                               ' ')
                        || RPAD (
                                  v_segment1
                               || '.'
                               || v_segment2
                               || '.'
                               || v_segment3
                               || '.'
                               || v_segment4
                               || '.'
                               || v_segment5
                               || '.'
                               || v_segment6
                               || '.'
                               || v_segment7
                               || '.'
                               || v_segment8,
                               60,
                               ' ')
                        || CHR (13)
                        || CHR (10));
                ELSIF l_correct_rec.description LIKE 'FRGT%'
                THEN
                    -- ELEMENTS_IN_DFF - Start
                    IF l_correct_rec.unit_freight_amt IS NOT NULL
                    THEN
                        l_freight_cost   := l_correct_rec.unit_freight_amt;
                    ELSE
                        -- ELEMENTS_IN_DFF - End
                        l_freight_cost   :=
                            get_amount (
                                p_cost           => 'FREIGHT',
                                p_organization_id   =>
                                    l_correct_rec.organization_id,
                                p_inventory_item_id   =>
                                    l_correct_rec.inventory_item_id,
                                p_po_header_id   => l_correct_rec.po_header_id,
                                p_po_line_id     => l_correct_rec.po_line_id,
                                p_po_line_location_id   =>
                                    l_correct_rec.po_line_location_id);
                    END IF;

                    IF l_freight_cost != 0             --changed on 29/04/2016
                    THEN
                        l_freight_amt   :=
                            ROUND (
                                  l_freight_cost * ABS (v_quantity)
                                - NVL (l_correct_rec.reversed_Cr, 0),
                                2);
                    ELSE
                        l_freight_amt   := 0;
                    END IF;


                    insert_into_gl_iface (
                        p_ledger_id       => l_correct_rec.ledger_id,
                        --p_date_created          => l_correct_rec.asn_creation_date,--commented on 02/05/16
                        p_date_created    => l_correct_rec.Transaction_date, --added on 02/05/16
                        --p_currency_code         => 'USD',--commented as per CR#54
                        p_currency_code   => l_correct_rec.currency_code, --added as per CR#54
                        p_code_combination_id   =>
                            l_correct_rec.code_combination_id,
                        p_debit_amount    => NULL,
                        p_credit_amount   => l_freight_amt,
                        p_batch_name      => g_rev_cor_batch_name,
                        p_batch_desc      => g_rev_cor_batch_name,
                        p_journal_name    =>
                               l_correct_rec.Shipment_num
                            || '- Correct-'
                            || l_correct_rec.Shipment_line_id,
                        p_journal_desc    =>
                            g_rev_cor_batch_name || '-' || l_correct_rec.Shipment_num,
                        p_line_desc       =>
                               'FRGT'
                            || '-'
                            || l_correct_rec.Shipment_num
                            || ' '
                            || l_correct_rec.Shipment_line_id,
                        p_context         => v_reverse_corrected_context,
                        P_attribute1      => l_correct_rec.Shipment_line_id);

                    SELECT segment1, segment2, segment3,
                           segment4, segment5, segment6,
                           segment7, segment8
                      INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                     v_segment5, v_segment6, v_segment7,
                                     v_segment8
                      FROM gl_code_combinations
                     WHERE code_combination_id =
                           l_correct_rec.code_combination_id;

                    fnd_file.put_line (
                        fnd_file.output,
                           RPAD (p_region, 10, ' ')               --CCR0007979
                        || RPAD (l_correct_rec.po_num, 12, ' ')
                        || RPAD (l_correct_rec.Shipment_num, 25, ' ')
                        || RPAD (l_correct_rec.Item_Num, 20, ' ')
                        || RPAD (l_correct_rec.po_unit_price, 17, ' ')
                        || RPAD (l_freight_amt, 10, ' ')
                        || RPAD (g_rev_cor_batch_name, 47, ' ')
                        || RPAD (
                                  l_correct_rec.Shipment_num
                               || '- Correct-'
                               || l_correct_rec.Shipment_line_id,
                               40,
                               ' ')
                        || RPAD (
                                  'FRGT'
                               || '-'
                               || l_correct_rec.Shipment_num
                               || ' '
                               || l_correct_rec.Shipment_line_id,
                               50,
                               ' ')
                        || RPAD (
                                  v_segment1
                               || '.'
                               || v_segment2
                               || '.'
                               || v_segment3
                               || '.'
                               || v_segment4
                               || '.'
                               || v_segment5
                               || '.'
                               || v_segment6
                               || '.'
                               || v_segment7
                               || '.'
                               || v_segment8,
                               60,
                               ' ')
                        || CHR (13)
                        || CHR (10));
                ELSIF l_correct_rec.description LIKE 'FREIGHT_DU%'
                THEN
                    -- ELEMENTS_IN_DFF - Start
                    IF l_correct_rec.unit_freightdu_amt IS NOT NULL
                    THEN
                        l_freightdu_cost   :=
                            l_correct_rec.unit_freightdu_amt;
                    ELSE
                        -- ELEMENTS_IN_DFF - End
                        l_freightdu_cost   :=
                            get_amount (
                                p_cost           => 'FREIGHT DU',
                                p_organization_id   =>
                                    l_correct_rec.organization_id,
                                p_inventory_item_id   =>
                                    l_correct_rec.inventory_item_id,
                                p_po_header_id   => l_correct_rec.po_header_id,
                                p_po_line_id     => l_correct_rec.po_line_id,
                                p_po_line_location_id   =>
                                    l_correct_rec.po_line_location_id);
                    END IF;

                    IF l_freightdu_cost != 0
                    THEN
                        l_freightdu_amt   :=
                            ROUND (
                                  l_freightdu_cost * ABS (v_quantity)
                                - NVL (l_correct_rec.reversed_Cr, 0),
                                2);
                    ELSE
                        l_freightdu_amt   := 0;
                    END IF;

                    insert_into_gl_iface (
                        p_ledger_id       => l_correct_rec.ledger_id,
                        --p_date_created          => l_correct_rec.asn_creation_date,--commented on 02/05/16
                        p_date_created    => l_correct_rec.Transaction_date, --added on 02/05/16
                        --p_currency_code         => 'USD',--commented as per CR#54
                        p_currency_code   => l_correct_rec.currency_code, --added as per CR#54
                        p_code_combination_id   =>
                            l_correct_rec.code_combination_id,
                        p_debit_amount    => NULL,
                        p_credit_amount   => l_freightdu_amt,
                        p_batch_name      => g_rev_cor_batch_name,
                        p_batch_desc      => g_rev_cor_batch_name,
                        p_journal_name    =>
                               l_correct_rec.Shipment_num
                            || '- Correct-'
                            || l_correct_rec.Shipment_line_id,
                        p_journal_desc    =>
                            g_rev_cor_batch_name || '-' || l_correct_rec.Shipment_num,
                        p_line_desc       =>
                               'FREIGHT_DU'
                            || '-'
                            || l_correct_rec.Shipment_num
                            || ' '
                            || l_correct_rec.Shipment_line_id,
                        p_context         => v_reverse_corrected_context,
                        P_attribute1      => l_correct_rec.Shipment_line_id);

                    SELECT segment1, segment2, segment3,
                           segment4, segment5, segment6,
                           segment7, segment8
                      INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                     v_segment5, v_segment6, v_segment7,
                                     v_segment8
                      FROM gl_code_combinations
                     WHERE code_combination_id =
                           l_correct_rec.code_combination_id;

                    fnd_file.put_line (
                        fnd_file.output,
                           RPAD (p_region, 10, ' ')               --CCR0007979
                        || RPAD (l_correct_rec.po_num, 12, ' ')
                        || RPAD (l_correct_rec.Shipment_num, 25, ' ')
                        || RPAD (l_correct_rec.Item_Num, 20, ' ')
                        || RPAD (l_correct_rec.po_unit_price, 17, ' ')
                        || RPAD (l_freightdu_amt, 10, ' ')
                        || RPAD (g_rev_cor_batch_name, 47, ' ')
                        || RPAD (
                                  l_correct_rec.Shipment_num
                               || '- Correct-'
                               || l_correct_rec.Shipment_line_id,
                               40,
                               ' ')
                        || RPAD (
                                  'FREIGHT_DU'
                               || '-'
                               || l_correct_rec.Shipment_num
                               || ' '
                               || l_correct_rec.Shipment_line_id,
                               50,
                               ' ')
                        || RPAD (
                                  v_segment1
                               || '.'
                               || v_segment2
                               || '.'
                               || v_segment3
                               || '.'
                               || v_segment4
                               || '.'
                               || v_segment5
                               || '.'
                               || v_segment6
                               || '.'
                               || v_segment7
                               || '.'
                               || v_segment8,
                               60,
                               ' ')
                        || CHR (13)
                        || CHR (10));
                ELSIF l_correct_rec.description LIKE 'OH DUTY%'
                THEN
                    -- ELEMENTS_IN_DFF - Start
                    IF l_correct_rec.unit_ohduty_amt IS NOT NULL
                    THEN
                        l_ohduty_cost   := l_correct_rec.unit_ohduty_amt;
                    ELSE
                        -- ELEMENTS_IN_DFF - End
                        l_ohduty_cost   :=
                            get_amount (
                                p_cost           => 'OH DUTY',
                                p_organization_id   =>
                                    l_correct_rec.organization_id,
                                p_inventory_item_id   =>
                                    l_correct_rec.inventory_item_id,
                                p_po_header_id   => l_correct_rec.po_header_id,
                                p_po_line_id     => l_correct_rec.po_line_id,
                                p_po_line_location_id   =>
                                    l_correct_rec.po_line_location_id);
                    END IF;

                    IF l_ohduty_cost != 0
                    THEN
                        l_ohduty_amt   :=
                            ROUND (
                                  l_ohduty_cost * ABS (v_quantity)
                                - NVL (l_correct_rec.reversed_cr, 0),
                                2);
                    ELSE
                        l_ohduty_amt   := 0;
                    END IF;


                    insert_into_gl_iface (
                        p_ledger_id       => l_correct_rec.ledger_id,
                        --p_date_created          => l_correct_rec.asn_creation_date,--commented on 02/05/16
                        p_date_created    => l_correct_rec.Transaction_date, --added on 02/05/16
                        --p_currency_code         => 'USD',--commented as per CR#54
                        p_currency_code   => l_correct_rec.currency_code, --added as per CR#54
                        p_code_combination_id   =>
                            l_correct_rec.code_combination_id,
                        p_debit_amount    => NULL,
                        p_credit_amount   => l_ohduty_amt,
                        p_batch_name      => g_rev_cor_batch_name,
                        p_batch_desc      => g_rev_cor_batch_name,
                        p_journal_name    =>
                               l_correct_rec.Shipment_num
                            || '- Correct-'
                            || l_correct_rec.Shipment_line_id,
                        p_journal_desc    =>
                            g_rev_cor_batch_name || '-' || l_correct_rec.Shipment_num,
                        p_line_desc       =>
                               'OH DUTY'
                            || '-'
                            || l_correct_rec.Shipment_num
                            || ' '
                            || l_correct_rec.Shipment_line_id,
                        p_context         => v_reverse_corrected_context,
                        P_attribute1      => l_correct_rec.Shipment_line_id);

                    SELECT segment1, segment2, segment3,
                           segment4, segment5, segment6,
                           segment7, segment8
                      INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                     v_segment5, v_segment6, v_segment7,
                                     v_segment8
                      FROM gl_code_combinations
                     WHERE code_combination_id =
                           l_correct_rec.code_combination_id;

                    fnd_file.put_line (
                        fnd_file.output,
                           RPAD (p_region, 10, ' ')               --CCR0007979
                        || RPAD (l_correct_rec.po_num, 12, ' ')
                        || RPAD (l_correct_rec.Shipment_num, 25, ' ')
                        || RPAD (l_correct_rec.Item_Num, 20, ' ')
                        || RPAD (l_correct_rec.po_unit_price, 17, ' ')
                        || RPAD (l_ohduty_amt, 10, ' ')
                        || RPAD (g_rev_cor_batch_name, 47, ' ')
                        || RPAD (
                                  l_correct_rec.Shipment_num
                               || '- Correct-'
                               || l_correct_rec.Shipment_line_id,
                               40,
                               ' ')
                        || RPAD (
                                  'OH DUTY'
                               || '-'
                               || l_correct_rec.Shipment_num
                               || ' '
                               || l_correct_rec.Shipment_line_id,
                               50,
                               ' ')
                        || RPAD (
                                  v_segment1
                               || '.'
                               || v_segment2
                               || '.'
                               || v_segment3
                               || '.'
                               || v_segment4
                               || '.'
                               || v_segment5
                               || '.'
                               || v_segment6
                               || '.'
                               || v_segment7
                               || '.'
                               || v_segment8,
                               60,
                               ' ')
                        || CHR (13)
                        || CHR (10));
                ELSIF l_correct_rec.description LIKE 'OH NONDUTY%'
                THEN
                    -- ELEMENTS_IN_DFF - Start
                    IF l_correct_rec.unit_oh_nonduty_amt IS NOT NULL
                    THEN
                        l_oh_nonduty_cost   :=
                            l_correct_rec.unit_oh_nonduty_amt;
                    ELSE
                        -- ELEMENTS_IN_DFF - End
                        l_oh_nonduty_cost   :=
                            get_amount (
                                p_cost           => 'OH NONDUTY',
                                p_organization_id   =>
                                    l_correct_rec.organization_id,
                                p_inventory_item_id   =>
                                    l_correct_rec.inventory_item_id,
                                p_po_header_id   => l_correct_rec.po_header_id,
                                p_po_line_id     => l_correct_rec.po_line_id,
                                p_po_line_location_id   =>
                                    l_correct_rec.po_line_location_id);
                    END IF;

                    IF l_oh_nonduty_cost != 0
                    THEN
                        l_oh_nonduty_amt   :=
                            ROUND (
                                  l_oh_nonduty_cost * ABS (v_quantity)
                                - NVL (l_correct_rec.reversed_cr, 0),
                                2);
                    ELSE
                        l_oh_nonduty_amt   := 0;
                    END IF;

                    insert_into_gl_iface (
                        p_ledger_id       => l_correct_rec.ledger_id,
                        --p_date_created          => l_correct_rec.asn_creation_date,--commented on 02/05/16
                        p_date_created    => l_correct_rec.Transaction_date, --added on 02/05/16
                        --p_currency_code         => 'USD',--commented as per CR#54
                        p_currency_code   => l_correct_rec.currency_code, --added as per CR#54
                        p_code_combination_id   =>
                            l_correct_rec.code_combination_id,
                        p_debit_amount    => NULL,
                        p_credit_amount   => l_oh_nonduty_amt,
                        p_batch_name      => g_rev_cor_batch_name,
                        p_batch_desc      => g_rev_cor_batch_name,
                        p_journal_name    =>
                               l_correct_rec.Shipment_num
                            || '- Correct-'
                            || l_correct_rec.Shipment_line_id,
                        p_journal_desc    =>
                            g_rev_cor_batch_name || '-' || l_correct_rec.Shipment_num,
                        p_line_desc       =>
                               'OH NONDUTY'
                            || '-'
                            || l_correct_rec.Shipment_num
                            || ' '
                            || l_correct_rec.Shipment_line_id,
                        p_context         => v_reverse_corrected_context,
                        P_attribute1      => l_correct_rec.Shipment_line_id);

                    SELECT segment1, segment2, segment3,
                           segment4, segment5, segment6,
                           segment7, segment8
                      INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                     v_segment5, v_segment6, v_segment7,
                                     v_segment8
                      FROM gl_code_combinations
                     WHERE code_combination_id =
                           l_correct_rec.code_combination_id;

                    fnd_file.put_line (
                        fnd_file.output,
                           RPAD (p_region, 10, ' ')               --CCR0007979
                        || RPAD (l_correct_rec.po_num, 12, ' ')
                        || RPAD (l_correct_rec.Shipment_num, 25, ' ')
                        || RPAD (l_correct_rec.Item_Num, 20, ' ')
                        || RPAD (l_correct_rec.po_unit_price, 17, ' ')
                        || RPAD (l_oh_nonduty_amt, 10, ' ')
                        || RPAD (g_rev_cor_batch_name, 47, ' ')
                        || RPAD (
                                  l_correct_rec.Shipment_num
                               || '- Correct-'
                               || l_correct_rec.Shipment_line_id,
                               40,
                               ' ')
                        || RPAD (
                                  'OH NONDUTY'
                               || '-'
                               || l_correct_rec.Shipment_num
                               || ' '
                               || l_correct_rec.Shipment_line_id,
                               50,
                               ' ')
                        || RPAD (
                                  v_segment1
                               || '.'
                               || v_segment2
                               || '.'
                               || v_segment3
                               || '.'
                               || v_segment4
                               || '.'
                               || v_segment5
                               || '.'
                               || v_segment6
                               || '.'
                               || v_segment7
                               || '.'
                               || v_segment8,
                               60,
                               ' ')
                        || CHR (13)
                        || CHR (10));
                ELSIF l_correct_rec.description LIKE 'OVERHEAD%'
                THEN
                    -- ELEMENTS_IN_DFF - Start
                    IF l_correct_rec.unit_overheads_amt IS NOT NULL
                    THEN
                        l_overheads_cost   :=
                            l_correct_rec.unit_overheads_amt;
                    ELSE
                        -- ELEMENTS_IN_DFF - End
                        l_overheads_cost   :=
                            get_amount (
                                p_cost           => 'OVERHEADS ',
                                p_organization_id   =>
                                    l_correct_rec.organization_id,
                                p_inventory_item_id   =>
                                    l_correct_rec.inventory_item_id,
                                p_po_header_id   => l_correct_rec.po_header_id,
                                p_po_line_id     => l_correct_rec.po_line_id,
                                p_po_line_location_id   =>
                                    l_correct_rec.po_line_location_id);
                    END IF;

                    IF l_overheads_cost != 0
                    THEN
                        l_overheads_amt   :=
                            ROUND (
                                  l_overheads_cost * ABS (v_quantity)
                                - NVL (l_correct_rec.reversed_dr, 0),
                                2);
                    ELSE
                        l_overheads_amt   := 0;
                    END IF;

                    insert_into_gl_iface (
                        p_ledger_id       => l_correct_rec.ledger_id,
                        --p_date_created          => l_correct_rec.asn_creation_date,--commented on 02/05/16
                        p_date_created    => l_correct_rec.Transaction_date, --added on 02/05/16
                        --p_currency_code         => 'USD',--commented as per CR#54
                        p_currency_code   => l_correct_rec.currency_code, --added as per CR#54
                        p_code_combination_id   =>
                            l_correct_rec.code_combination_id,
                        p_debit_amount    => l_overheads_amt,
                        p_credit_amount   => NULL,
                        p_batch_name      => g_rev_cor_batch_name,
                        p_batch_desc      => g_rev_cor_batch_name,
                        p_journal_name    =>
                               l_correct_rec.Shipment_num
                            || '- Correct-'
                            || l_correct_rec.Shipment_line_id,
                        p_journal_desc    =>
                            g_rev_cor_batch_name || '-' || l_correct_rec.Shipment_num,
                        p_line_desc       =>
                               'OVERHEADS '
                            || '-'
                            || l_correct_rec.Shipment_num
                            || ' '
                            || l_correct_rec.Shipment_line_id,
                        p_context         => v_reverse_corrected_context,
                        P_attribute1      => l_correct_rec.Shipment_line_id);

                    SELECT segment1, segment2, segment3,
                           segment4, segment5, segment6,
                           segment7, segment8
                      INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                     v_segment5, v_segment6, v_segment7,
                                     v_segment8
                      FROM gl_code_combinations
                     WHERE code_combination_id =
                           l_correct_rec.code_combination_id;

                    fnd_file.put_line (
                        fnd_file.output,
                           RPAD (p_region, 10, ' ')               --CCR0007979
                        || RPAD (l_correct_rec.po_num, 12, ' ')
                        || RPAD (l_correct_rec.Shipment_num, 25, ' ')
                        || RPAD (l_correct_rec.Item_Num, 20, ' ')
                        || RPAD (l_correct_rec.po_unit_price, 17, ' ')
                        || RPAD (l_overheads_amt, 10, ' ')
                        || RPAD (g_rev_cor_batch_name, 47, ' ')
                        || RPAD (
                                  l_correct_rec.Shipment_num
                               || '- Correct-'
                               || l_correct_rec.Shipment_line_id,
                               40,
                               ' ')
                        || RPAD (
                                  'OVERHEADS '
                               || '-'
                               || l_correct_rec.Shipment_num
                               || ' '
                               || l_correct_rec.Shipment_line_id,
                               50,
                               ' ')
                        || RPAD (
                                  v_segment1
                               || '.'
                               || v_segment2
                               || '.'
                               || v_segment3
                               || '.'
                               || v_segment4
                               || '.'
                               || v_segment5
                               || '.'
                               || v_segment6
                               || '.'
                               || v_segment7
                               || '.'
                               || v_segment8,
                               60,
                               ' ')
                        || CHR (13)
                        || CHR (10));
                ELSIF l_correct_rec.description LIKE 'Factory Cost%'
                THEN
                    l_factorycost_cost   :=
                        get_amount (
                            p_cost           => 'Factory Cost',
                            p_organization_id   =>
                                l_correct_rec.organization_id,
                            p_inventory_item_id   =>
                                l_correct_rec.inventory_item_id,
                            p_po_header_id   => l_correct_rec.po_header_id,
                            p_po_line_id     => l_correct_rec.po_line_id,
                            p_po_line_location_id   =>
                                l_correct_rec.po_line_location_id);


                    IF l_factorycost_cost != 0
                    THEN
                        l_factorycost_amt   :=
                            ROUND (
                                  l_factorycost_cost * ABS (v_quantity)
                                - NVL (l_correct_rec.reversed_cr, 0),
                                2);
                    ELSE
                        l_factorycost_amt   := 0;
                    END IF;

                    insert_into_gl_iface (
                        p_ledger_id       => l_correct_rec.ledger_id,
                        --p_date_created          => l_correct_rec.asn_creation_date,--commented on 02/05/16
                        p_date_created    => l_correct_rec.Transaction_date, --added on 02/05/16
                        --p_currency_code         => 'USD',--commented as per CR#54
                        p_currency_code   => l_correct_rec.currency_code, --added as per CR#54
                        p_code_combination_id   =>
                            l_correct_rec.code_combination_id,
                        p_debit_amount    => NULL,
                        p_credit_amount   => l_factorycost_amt,
                        p_batch_name      => g_rev_cor_batch_name,
                        p_batch_desc      => g_rev_cor_batch_name,
                        p_journal_name    =>
                               l_correct_rec.Shipment_num
                            || '- Correct-'
                            || l_correct_rec.Shipment_line_id,
                        p_journal_desc    =>
                            g_rev_cor_batch_name || '-' || l_correct_rec.Shipment_num,
                        p_line_desc       =>
                               'Factory Cost'
                            || '-'
                            || l_correct_rec.Shipment_num
                            || ' '
                            || l_correct_rec.Shipment_line_id,
                        p_context         => v_reverse_corrected_context,
                        P_attribute1      => l_correct_rec.Shipment_line_id);

                    SELECT segment1, segment2, segment3,
                           segment4, segment5, segment6,
                           segment7, segment8
                      INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                     v_segment5, v_segment6, v_segment7,
                                     v_segment8
                      FROM gl_code_combinations
                     WHERE code_combination_id =
                           l_correct_rec.code_combination_id;

                    fnd_file.put_line (
                        fnd_file.output,
                           RPAD (p_region, 10, ' ')               --CCR0007979
                        || RPAD (l_correct_rec.po_num, 12, ' ')
                        || RPAD (l_correct_rec.Shipment_num, 25, ' ')
                        || RPAD (l_correct_rec.Item_Num, 20, ' ')
                        || RPAD (l_correct_rec.po_unit_price, 17, ' ')
                        || RPAD (l_factorycost_amt, 10, ' ')
                        || RPAD (g_rev_cor_batch_name, 47, ' ')
                        || RPAD (
                                  l_correct_rec.Shipment_num
                               || '- Correct-'
                               || l_correct_rec.Shipment_line_id,
                               40,
                               ' ')
                        || RPAD (
                                  'Factory Cost'
                               || '-'
                               || l_correct_rec.Shipment_num
                               || ' '
                               || l_correct_rec.Shipment_line_id,
                               50,
                               ' ')
                        || RPAD (
                                  v_segment1
                               || '.'
                               || v_segment2
                               || '.'
                               || v_segment3
                               || '.'
                               || v_segment4
                               || '.'
                               || v_segment5
                               || '.'
                               || v_segment6
                               || '.'
                               || v_segment7
                               || '.'
                               || v_segment8,
                               60,
                               ' ')
                        || CHR (13)
                        || CHR (10));
                ELSIF l_correct_rec.description LIKE 'In Transit%'
                THEN
                    l_intransit_cost   :=
                        get_amount (
                            p_cost           => 'In Transit',
                            p_organization_id   =>
                                l_correct_rec.organization_id,
                            p_inventory_item_id   =>
                                l_correct_rec.inventory_item_id,
                            p_po_header_id   => l_correct_rec.po_header_id,
                            p_po_line_id     => l_correct_rec.po_line_id,
                            p_po_line_location_id   =>
                                l_correct_rec.po_line_location_id);

                    IF l_intransit_cost != 0
                    THEN
                        l_intransit_amt   :=
                            ROUND (
                                  l_intransit_cost * ABS (v_quantity)
                                - NVL (l_correct_rec.reversed_dr, 0),
                                2);
                    ELSE
                        l_intransit_amt   := 0;
                    END IF;


                    insert_into_gl_iface (
                        p_ledger_id       => l_correct_rec.ledger_id,
                        --p_date_created          => l_correct_rec.asn_creation_date,--commented on 02/05/16
                        p_date_created    => l_correct_rec.Transaction_date, --added on 02/05/16
                        --p_currency_code         => 'USD',--commented as per CR#54
                        p_currency_code   => l_correct_rec.currency_code, --added as per CR#54
                        p_code_combination_id   =>
                            l_correct_rec.code_combination_id,
                        p_debit_amount    => l_intransit_amt,
                        p_credit_amount   => NULL,
                        p_batch_name      => g_rev_cor_batch_name,
                        p_batch_desc      => g_rev_cor_batch_name,
                        p_journal_name    =>
                               l_correct_rec.Shipment_num
                            || '- Correct-'
                            || l_correct_rec.Shipment_line_id,
                        p_journal_desc    =>
                            g_rev_cor_batch_name || '-' || l_correct_rec.Shipment_num,
                        p_line_desc       =>
                               'In Transit'
                            || '-'
                            || l_correct_rec.Shipment_num
                            || ' '
                            || l_correct_rec.Shipment_line_id,
                        p_context         => v_reverse_corrected_context,
                        P_attribute1      => l_correct_rec.Shipment_line_id);

                    SELECT segment1, segment2, segment3,
                           segment4, segment5, segment6,
                           segment7, segment8
                      INTO v_segment1, v_segment2, v_segment3, v_segment4,
                                     v_segment5, v_segment6, v_segment7,
                                     v_segment8
                      FROM gl_code_combinations
                     WHERE code_combination_id =
                           l_correct_rec.code_combination_id;

                    fnd_file.put_line (
                        fnd_file.output,
                           RPAD (p_region, 10, ' ')               --CCR0007979
                        || RPAD (l_correct_rec.po_num, 12, ' ')
                        || RPAD (l_correct_rec.Shipment_num, 25, ' ')
                        || RPAD (l_correct_rec.Item_Num, 20, ' ')
                        || RPAD (l_correct_rec.po_unit_price, 17, ' ')
                        || RPAD (l_intransit_amt, 10, ' ')
                        || RPAD (g_rev_cor_batch_name, 47, ' ')
                        || RPAD (
                                  l_correct_rec.Shipment_num
                               || '- Correct-'
                               || l_correct_rec.Shipment_line_id,
                               40,
                               ' ')
                        || RPAD (
                                  'In Transit'
                               || '-'
                               || l_correct_rec.Shipment_num
                               || ' '
                               || l_correct_rec.Shipment_line_id,
                               50,
                               ' ')
                        || RPAD (
                                  v_segment1
                               || '.'
                               || v_segment2
                               || '.'
                               || v_segment3
                               || '.'
                               || v_segment4
                               || '.'
                               || v_segment5
                               || '.'
                               || v_segment6
                               || '.'
                               || v_segment7
                               || '.'
                               || v_segment8,
                               60,
                               ' ')
                        || CHR (13)
                        || CHR (10));
                END IF;

                SELECT COUNT (attribute1)
                  INTO v_count
                  FROM gl_interface
                 WHERE     context = v_reverse_corrected_context
                       AND attribute1 = l_correct_rec.Shipment_line_id;

                IF v_count > 0
                THEN
                    UPDATE APPS.RCV_TRANSACTIONS
                       --change starts as per defect#749
                       --SET ATTRIBUTE3 = 'Y'
                       SET comments   = 'Y'
                     --change end as per defect#749
                     WHERE     SHIPMENT_LINE_ID =
                               l_correct_rec.shipment_line_id
                           AND transaction_type = 'CORRECT';
                END IF;


                l_reversal_count   := l_reversal_count + 1;

                -- COMMIT_BATCH_SIZE - Start
                IF l_reversal_count >= g_commit_batch_size
                --IF l_reversal_count >= 500
                -- COMMIT_BATCH_SIZE - End
                THEN
                    COMMIT;
                    l_reversal_count   := 0;
                END IF;
            ELSE --If these correction records are not to be acted on then mark them as processed.
                UPDATE APPS.RCV_TRANSACTIONS
                   --change starts as per defect#749
                   --SET ATTRIBUTE3 = 'Y'
                   SET comments   = 'Y'
                 --change end as per defect#749
                 WHERE     SHIPMENT_LINE_ID = l_correct_rec.shipment_line_id
                       AND transaction_type = 'CORRECT';
            END IF;
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
               'Correction Interface End : '
            || TO_CHAR (SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            perrproc   := 2;
            psqlstat   := SQLERRM;
            fnd_file.put_line (fnd_file.LOG, 'Exception4: ' || SQLERRM);
    END create_correction_interface;
--changes as per CR#54 ends

END XXDOPO_AUTO_INTRANSIT;
/
