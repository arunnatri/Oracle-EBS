--
-- XXD_ENTERED_QUANTITIES_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:45 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ENTERED_QUANTITIES_PKG"
AS
    /*
     *********************************************************************************************
      * Package         : APPS.XXD_ENTERED_QUANTITIES_PKG
      * Author          : BT Technology Team
      * Created         : 24-APRIL-2015
      * Program Name  :
      * Description     :
      *
      * Modification  :
      *-----------------------------------------------------------------------------------------------
      *     Date         Developer             Version     Description
      *-----------------------------------------------------------------------------------------------
      *   24-APRIL-2015  BT Technology Team     V1.1         Development
      *   27-JUN-2016  BT Technology Team     V1.1         Development
      ************************************************************************************************/

    /*
          ====================================================================================================================
              Declaration Of Function To Get The First Monday
          ====================================================================================================================
    */

    FUNCTION get_first_monday (p_date IN DATE)
        RETURN DATE
    IS
        ld_first_date   DATE := NULL;
    BEGIN
        SELECT CASE
                   WHEN TRUNC (TO_DATE (p_date, 'DD-MON-YY'), 'DAY') + 1 <
                        TRUNC (TO_DATE (p_date, 'DD-MON-YY'), 'MONTH')
                   THEN
                       TRUNC (TO_DATE (p_date, 'DD-MON-YY'), 'DAY') + 1
                   ELSE
                       NEXT_DAY (
                           TRUNC (TO_DATE (p_date, 'DD-MON-YY'), 'MONTH'),
                           'MON')
               END fmd
          INTO ld_first_date
          FROM DUAL;

        RETURN ld_first_date;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Function GET_FIRST_MONDAY Getting No Data ' || SQLERRM);
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error When Calling The Function GET_FIRST_MONDAY: '
                || SQLERRM);
            RETURN ld_first_date;
    END;

    PROCEDURE get_entered_quantities (p_errbuf          OUT VARCHAR2,
                                      p_retcode         OUT VARCHAR2,
                                      p_f_date       IN     VARCHAR2,
                                      p_t_date       IN     VARCHAR2,
                                      p_debug_mode   IN     CHAR)
    AS
        /*
              ====================================================================================================================
                  Declaration Of Cursor
              ====================================================================================================================
        */
        CURSOR get_entered_quantities_c (cp_from_date DATE, cp_to_date DATE)
        IS
            SELECT xx.sdate                                  --added newly NRK
                           ,
                   iid_to_sku (inventory_item_id)
                       level1,
                   demand_class_code
                       level2,
                   (SELECT mp.organization_code
                      FROM mtl_parameters mp
                     WHERE mp.organization_id = xx.ship_from_org_id)
                       level3,
                   (SELECT hps.party_name
                      FROM hz_cust_site_uses_all hcsua, hz_cust_acct_sites_all hcasa, hz_cust_accounts hca,
                           hz_parties hps
                     WHERE     hcsua.cust_acct_site_id =
                               hcasa.cust_acct_site_id
                           AND hcasa.cust_account_id = hca.cust_account_id
                           AND hca.party_id = hps.party_id
                           AND hcsua.site_use_id = xx.ship_to_org_id)
                       level4,
                   (SELECT NVL (SUM (l.ordered_quantity), 0)
                      FROM oe_order_lines_all l
                     WHERE     l.inventory_item_id = xx.inventory_item_id
                           AND l.demand_class_code = xx.demand_class_code
                           AND l.ship_from_org_id = xx.ship_from_org_id
                           AND l.ship_to_org_id = xx.ship_to_org_id
                           AND l.flow_status_code = 'ENTERED')
                       dec_enter_quantity,
                   (SELECT NVL (SUM (l.ordered_quantity), 0)
                      FROM oe_order_lines_all l
                     WHERE     l.inventory_item_id = xx.inventory_item_id
                           AND l.demand_class_code = xx.demand_class_code
                           AND l.ship_from_org_id = xx.ship_from_org_id
                           AND l.ship_to_org_id = xx.ship_to_org_id --AND L.FLOW_STATUS_CODE    IN('ENTERED','BOOKED')
                                                                   )
                       sales_override
              FROM (  SELECT (apps.xxd_entered_quantities_pkg.get_first_monday (--ooha.ordered_date))                                -- Commented by BT Team on 13May2016
                                                                                ooha.request_date)) -- Added by BT Team on 13May2016
                                                                                                    sdate --added newly NRK
                                                                                                         , oola.inventory_item_id, oola.demand_class_code,
                             oola.ship_from_org_id, oola.ship_to_org_id
                        FROM oe_order_headers_all ooha, oe_order_lines_all oola, hz_cust_site_uses_all hcsua,
                             hz_cust_acct_sites_all hcasa, hz_cust_accounts hca
                       WHERE     ooha.header_id = oola.header_id
                             --and ooha.ordered_date                                 -- Commented by BT Team on 13May2016
                             AND ooha.request_date -- Added by BT Team on 13May2016
                                                   BETWEEN cp_from_date
                                                       AND cp_to_date
                             AND oola.flow_status_code IN ('ENTERED', 'BOOKED')
                             AND hcsua.cust_acct_site_id =
                                 hcasa.cust_acct_site_id
                             AND hcasa.cust_account_id = hca.cust_account_id
                             AND hca.sales_channel_code = 'DISTRIBUTOR'
                             AND hcsua.site_use_id = oola.ship_to_org_id
                             AND oola.ship_from_org_id NOT IN
                                     (SELECT mp.organization_id
                                        FROM mtl_parameters mp
                                       WHERE mp.organization_code = 'APB') -- Added by BT Team on 01Jun2016 #To remove the datafeed for org in DEC:APB
                    GROUP BY oola.inventory_item_id, oola.demand_class_code, oola.ship_from_org_id,
                             oola.ship_to_org_id, (apps.xxd_entered_quantities_pkg.get_first_monday (-- ooha.ordered_date))            --added newly NRK -- Commented by BT Team on 13May2016
                                                                                                     ooha.request_date)) -- Added by BT Team on 13May2016
                                                                                                                        )
                   xx;

        /*   ====================================================================================================================
            Declartion of Local Variables
        ====================================================================================================================*/

        ld_from_date   DATE;
        ld_to_date     DATE;
        ln_count       NUMBER;
        lv_instance    VARCHAR2 (10) := NULL;
    BEGIN
        ld_from_date   := fnd_date.canonical_to_date (p_f_date);
        fnd_file.put_line (fnd_file.LOG, 'From Date ' || ld_from_date);

        ld_to_date     := fnd_date.canonical_to_date (p_t_date);
        fnd_file.put_line (fnd_file.LOG, 'From Date ' || ld_to_date);

        fnd_file.put_line (fnd_file.LOG, 'Before Open The Cursor');

        --To get the Instance Code
        BEGIN
            SELECT mai.instance_code
              INTO lv_instance
              FROM msc.msc_apps_instances@bt_ebs_to_ascp mai;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Unable to derive Instance Code : ' || SQLCODE || SQLERRM);
        END;

        -- Start of changes by BT Team on 16Jun2016
        fnd_file.put_line (fnd_file.LOG, 'Truncating the tables...');

        fnd_file.put_line (
            fnd_file.LOG,
            'Demantra.biio_dist_entered_quantity@bt_ebs_to_ascp.. ');

        DELETE FROM demantra.biio_dist_entered_quantity@bt_ebs_to_ascp;

        COMMIT;

        fnd_file.put_line (
            fnd_file.LOG,
            'Demantra.BIIO_DIST_ENTERED_QUANTITY_ERR@bt_ebs_to_ascp.. ');

        DELETE FROM demantra.BIIO_DIST_ENTERED_QUANTITY_ERR@bt_ebs_to_ascp;

        COMMIT;
        -- End of changes by BT Team on 16Jun2016

        fnd_file.put_line (fnd_file.LOG, 'Inserting data to tables...');

        FOR lcu_get_entered_quantities_rec
            IN get_entered_quantities_c (ld_from_date, ld_to_date)
        LOOP
            BEGIN
                IF (p_debug_mode = 'Yes')
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'INSERTING THE VALUES -'
                        || lcu_get_entered_quantities_rec.sdate
                        || '-'
                        || lcu_get_entered_quantities_rec.level1
                        || '-'
                        || lcu_get_entered_quantities_rec.level2
                        || '-'
                        || lcu_get_entered_quantities_rec.level3
                        || '-'
                        || lcu_get_entered_quantities_rec.level4
                        || '-'
                        || lcu_get_entered_quantities_rec.dec_enter_quantity
                        || '-'
                        || lcu_get_entered_quantities_rec.sales_override);
                END IF;

                IF     lcu_get_entered_quantities_rec.sales_override = 0
                   AND lcu_get_entered_quantities_rec.dec_enter_quantity = 0
                THEN
                    NULL;                    -- Don't Insert if both are Zero.
                ELSE
                    INSERT INTO demantra.biio_dist_entered_quantity@bt_ebs_to_ascp (
                                    sdate,
                                    level1,
                                    level2,
                                    level3,
                                    level4,
                                    dec_distributor_sales,
                                    dec_entered_qty,
                                    sales_override)
                             VALUES (
                                        lcu_get_entered_quantities_rec.sdate,
                                        lcu_get_entered_quantities_rec.level1,
                                        lcu_get_entered_quantities_rec.level2,
                                           lv_instance
                                        || ':'
                                        || lcu_get_entered_quantities_rec.level3,
                                        lcu_get_entered_quantities_rec.level4,
                                        lcu_get_entered_quantities_rec.sales_override,
                                        lcu_get_entered_quantities_rec.dec_enter_quantity,
                                        lcu_get_entered_quantities_rec.sales_override);
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    p_errbuf   := 2;
                    p_errbuf   := p_errbuf || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG,
                                       'UNEXP ERROR ' || SQLERRM);
                WHEN OTHERS
                THEN
                    p_errbuf   := 2;
                    fnd_file.put_line (fnd_file.LOG,
                                       'UNEXP ERROR ' || SQLERRM);
            END;
        END LOOP;

        COMMIT;

        IF (p_debug_mode = 'Yes')
        THEN
            SELECT COUNT (*)
              INTO ln_count
              FROM demantra.biio_dist_entered_quantity@bt_ebs_to_ascp;

            fnd_file.put_line (fnd_file.LOG,
                               'Count Of Rows In The Cursor  ' || ln_count);
            fnd_file.put_line (fnd_file.LOG, 'Close Of Cursor ');
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            IF (get_entered_quantities_c%ISOPEN)
            THEN
                CLOSE get_entered_quantities_c;
            END IF;

            p_errbuf   := 2;
            p_errbuf   := p_errbuf || SQLERRM;
            fnd_file.put_line (fnd_file.LOG, 'UNEXP ERROR ' || SQLERRM);
        WHEN OTHERS
        THEN
            IF (get_entered_quantities_c%ISOPEN)
            THEN
                CLOSE get_entered_quantities_c;
            END IF;

            p_errbuf   := 2;
            fnd_file.put_line (fnd_file.LOG, 'UNEXP ERROR ' || SQLERRM);
    END get_entered_quantities;
END xxd_entered_quantities_pkg;
/
