--
-- XXDO_NEGATIVE_ATP_REPORT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:34 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_NEGATIVE_ATP_REPORT_PKG"
IS
    /*******************************************************************************
    * $Header$
    * Program Name : XXDO_NEGATIVE_ATP_REPORT_PKG.pkb
    * Language     : PL/SQL
    * Description  :
    * History      :
    *
    * WHO            WHAT                                    WHEN
    * -------------- --------------------------------------- ---------------
    * BT_TECHNOLOGY        Original version.                       01-DEC-2015
    *
    *
    *******************************************************************************/

    FUNCTION beforeReport (P_ORGANIZATION_NAME IN VARCHAR2, P_PLAN_ID IN NUMBER, P_PLAN_DATE IN VARCHAR2
                           , P_FROM_DATE IN VARCHAR2, P_TO_DATE IN VARCHAR2)
        RETURN BOOLEAN
    IS
        CURSOR lc_negative_atp_data (P_ORGANIZATION_NAME VARCHAR2, P_PLAN_ID NUMBER, P_PLAN_DATE VARCHAR)
        IS
              SELECT mp.ORGANIZATION_ID ORGANIZATION_ID, ebsitm.BRAND BRAND, ebsitm.STYLE_NUMBER STYLE,
                     ebsitm.COLOR_CODE COLOR, ebsitm.ITEM_SIZE ITEM_SIZE, ebsitm.ITEM_NUMBER ITEM_NUMBER,
                     msi.SR_INVENTORY_ITEM_ID INVENTORY_ITEM_ID, x.DEMAND_CLASS DEMAND_CLASS, MIN (poh) NEGATIVITY
                FROM (SELECT alloc_Date alloc_Date, Tot_supply Supply_Qty, Tot_demand Demand_Qty,
                             Tot_supply - Tot_demand Net_Qty, SUM (Tot_supply - Tot_demand) OVER (PARTITION BY inventory_item_id, DEMAND_CLASS ORDER BY inventory_item_id, DEMAND_CLASS, ALLOC_DATE--ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                                                                                                                                                                                                   ) poh, DEMAND_CLASS,
                             inventory_item_id
                        FROM (  SELECT alloc_Date alloc_date, SUM (supply) tot_supply, SUM (demand) tot_demand,
                                       DEMAND_CLASS, inventory_item_id
                                  FROM (SELECT TRUNC (supply_date) alloc_date, allocated_quantity supply, 0 demand,
                                               DEMAND_CLASS, inventory_item_id
                                          FROM msc_alloc_supplies@BT_EBS_TO_ASCP
                                         WHERE     1 = 1
                                               -- AND inventory_item_id in (20007,20008,20006,154121)
                                               AND organization_id =
                                                   P_ORGANIZATION_NAME
                                               AND plan_id = P_PLAN_ID
                                        --AND demand_class = cp_demand_class
                                        UNION ALL
                                        SELECT DECODE (SIGN (TRUNC (demand_date) - TRUNC (TO_DATE (P_PLAN_DATE, 'DD-MON-YYYY'))), 1, TRUNC (demand_date), TRUNC (TO_DATE (P_PLAN_DATE, 'DD-MON-YYYY'))) Alloc_date, 0 Supply, allocated_quantity Demand,
                                               DEMAND_CLASS, inventory_item_id
                                          FROM msc_alloc_demands@BT_EBS_TO_ASCP
                                         WHERE     1 = 1
                                               --AND  inventory_item_id in (20007,20008,20006,154121)
                                               AND plan_id = P_PLAN_ID
                                               AND ORGANIZATION_ID =
                                                   P_ORGANIZATION_NAME)
                              GROUP BY inventory_item_id, DEMAND_CLASS, alloc_Date))
                     x,
                     MSC_SYSTEM_ITEMS@BT_EBS_TO_ASCP msi,
                     XXD_COMMON_ITEMS_V ebsitm,
                     mtl_parameters mp
               WHERE     x.INVENTORY_ITEM_ID = msi.INVENTORY_ITEM_ID
                     AND msi.SR_INVENTORY_ITEM_ID = ebsitm.INVENTORY_ITEM_ID
                     AND msi.ORGANIZATION_ID = ebsitm.ORGANIZATION_ID
                     AND ebsitm.ORGANIZATION_ID = mp.ORGANIZATION_ID
                     AND ebsitm.ORGANIZATION_ID = P_ORGANIZATION_NAME
                     AND msi.plan_id = P_PLAN_ID
            --and ebsitm.item_number='1001515-BLK-10'
            GROUP BY msi.SR_INVENTORY_ITEM_ID, x.demand_class, mp.ORGANIZATION_ID,
                     ebsitm.brand, ebsitm.STYLE_NUMBER, ebsitm.COLOR_CODE,
                     ebsitm.ITEM_SIZE, ebsitm.item_number
              HAVING MIN (poh) < 0
            ORDER BY ebsitm.BRAND, ebsitm.ITEM_NUMBER;
    BEGIN
        EXECUTE IMMEDIATE 'TRUNCATE TABLE XXDO.xxd_negative_level_tbl';

        FOR I
            IN lc_negative_atp_data (P_ORGANIZATION_NAME,
                                     P_PLAN_ID,
                                     P_PLAN_DATE)
        LOOP
            INSERT INTO xxdo.xxd_negative_level_tbl (SESSION_ID, ORGANIZATION_ID, BRAND, STYLE, COLOR, ITEM_SIZE, ITEM_NUMBER, INVENTORY_ITEM_ID, DEMAND_CLASS
                                                     , NEGATIVITY)
                 VALUES (SYS_CONTEXT ('userenv', 'sessionid'), i.ORGANIZATION_ID, i.BRAND, i.STYLE, i.COLOR, i.ITEM_SIZE, i.ITEM_NUMBER, i.INVENTORY_ITEM_ID, i.DEMAND_CLASS
                         , i.NEGATIVITY);

            COMMIT;
        END LOOP;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'ERROR:=' || SQLERRM);

            RETURN FALSE;
    END;
END XXDO_NEGATIVE_ATP_REPORT_PKG;
/
