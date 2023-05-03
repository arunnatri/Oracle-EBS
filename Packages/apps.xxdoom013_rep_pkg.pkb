--
-- XXDOOM013_REP_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:50 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOOM013_REP_PKG"
AS
    /******************************************************************************
       NAME: XXDOOM013_REP_PKG
       REP NAME:UK Item Tax Exemption Interface - Deckers

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0       11/29/2012     Shibu        1. Created this package for XXDOOM013_REP_PKG Process
    ******************************************************************************/

    PROCEDURE TAX_EXEMPT_ITEMS (PV_ERRBUF                OUT VARCHAR2,
                                PV_RETCODE               OUT VARCHAR2,
                                PN_CONTENT_OWNER_ID          NUMBER,
                                PV_TAX_RATE_CODE             VARCHAR2,
                                PV_EXEMPT_REASON             VARCHAR2,
                                PV_EXEMPT_START_DT           VARCHAR2,
                                PN_MST_INV_ORG               NUMBER,
                                PV_EXEMPT_TAX_CLASS_ID       NUMBER)
    IS
        -- New Exempt insert items
        CURSOR C_MAIN (PN_CONTENT_OWNER_ID NUMBER, PN_MST_INV_ORG NUMBER, PV_EXEMPT_TAX_CLASS_ID NUMBER
                       , PV_TAX_RATE_CODE VARCHAR2)
        IS
              SELECT mic.inventory_item_id, msi.organization_id, c.segment1 category,
                     msi.concatenated_segments item_number
                FROM apps.MTL_CATEGORY_SETS cs,
                     apps.mtl_categories c,
                     apps.mtl_item_categories mic,
                     apps.mtl_system_items_kfv msi,
                     (SELECT product_id, inventory_org_id, rate_modifier,
                             effective_from, effective_to, creation_date
                        FROM apps.zx_exceptions
                       WHERE     exception_class_code = 'ITEM'
                             AND exception_type_code = 'SPECIAL_RATE'
                             AND tax_rate_code = PV_TAX_RATE_CODE
                             AND content_owner_id = PN_CONTENT_OWNER_ID)
                     tax_exempt
               WHERE     cs.category_set_name = 'Tax Class'
                     AND cs.category_set_id = mic.category_set_id
                     AND mic.category_id = c.category_id
                     AND cs.structure_id = c.structure_id
                     AND mic.inventory_item_id = msi.inventory_item_id
                     AND mic.organization_id = msi.organization_id
                     --AND      msi.customer_order_enabled_flag = 'Y'
                     AND mic.organization_id = PN_MST_INV_ORG
                     AND c.category_id = PV_EXEMPT_TAX_CLASS_ID
                     AND msi.inventory_item_id = tax_exempt.product_id(+)
                     AND msi.organization_id = tax_exempt.INVENTORY_ORG_ID(+)
                     AND tax_exempt.rate_modifier(+) IS NULL
            --AND     msi.inventory_item_id   in( 4799820,4829471) --4829375
            ORDER BY item_number;

        ld_exempt_start_dt         DATE;
        l_tax_exception_id         NUMBER;
        l_count                    NUMBER := 0;
        l_cnt                      NUMBER := 0;

        lv_tax_rate_code           VARCHAR2 (50);
        lv_tax_status_code         VARCHAR2 (50);
        lv_tax                     VARCHAR2 (100);
        lv_tax_regime_code         VARCHAR2 (50);
        lv_tax_jurisdiction_code   VARCHAR2 (50);
        ln_TAX_JURISDICTION_ID     NUMBER;
    BEGIN
        ld_exempt_start_dt   :=
            apps.fnd_date.canonical_to_date (PV_EXEMPT_START_DT);
        apps.FND_FILE.PUT_LINE (
            apps.FND_FILE.OUTPUT,
            '========================================================================');
        apps.FND_FILE.PUT_LINE (
            apps.FND_FILE.OUTPUT,
            'CONTENT_OWNER ID   :' || PN_CONTENT_OWNER_ID);
        apps.FND_FILE.PUT_LINE (apps.FND_FILE.OUTPUT,
                                'TAX RATE ID        :' || PV_TAX_RATE_CODE);
        apps.FND_FILE.PUT_LINE (apps.FND_FILE.OUTPUT,
                                'EXCEMPT REASON     :' || PV_EXEMPT_REASON);
        apps.FND_FILE.PUT_LINE (
            apps.FND_FILE.OUTPUT,
               'EXEMPT START DATE  :'
            || TO_CHAR (ld_exempt_start_dt, 'DD-MON-YYYY'));
        apps.FND_FILE.PUT_LINE (apps.FND_FILE.OUTPUT,
                                'MST INV ORG        :' || PN_MST_INV_ORG);
        apps.FND_FILE.PUT_LINE (
            apps.FND_FILE.OUTPUT,
            'EXEMPT TAC CLASS   :' || PV_EXEMPT_TAX_CLASS_ID);
        apps.FND_FILE.PUT_LINE (
            apps.FND_FILE.OUTPUT,
            '========================================================================');


        BEGIN
            SELECT r.tax_rate_code, r.tax_status_code, r.tax,
                   r.tax_regime_code, r.tax_jurisdiction_code, zj.TAX_JURISDICTION_ID
              INTO lv_tax_rate_code, lv_tax_status_code, lv_tax, lv_tax_regime_code,
                                   lv_tax_jurisdiction_code, ln_TAX_JURISDICTION_ID
              FROM apps.zx_rates_b r, apps.ZX_JURISDICTIONS_B zj
             WHERE     r.active_flag = 'Y'
                   AND r.content_owner_id = PN_CONTENT_OWNER_ID
                   AND SYSDATE BETWEEN r.effective_from
                                   AND NVL (r.effective_to, SYSDATE + 1)
                   AND r.tax_rate_code = PV_TAX_RATE_CODE
                   AND r.tax_jurisdiction_code = zj.TAX_JURISDICTION_CODE;
        END;


        apps.FND_FILE.PUT_LINE (apps.FND_FILE.OUTPUT, 'Starting Insert');

        FOR i IN C_MAIN (PN_CONTENT_OWNER_ID, PN_MST_INV_ORG, PV_EXEMPT_TAX_CLASS_ID
                         , PV_TAX_RATE_CODE)
        LOOP
            BEGIN
                SELECT COUNT (*)
                  INTO l_cnt
                  FROM zx.zx_exceptions
                 WHERE     INVENTORY_ORG_ID = PN_MST_INV_ORG
                       AND PRODUCT_ID = i.inventory_item_id
                       AND CONTENT_OWNER_ID = PN_CONTENT_OWNER_ID
                       AND exception_class_code = 'ITEM'
                       AND exception_type_code = 'SPECIAL_RATE'
                       AND tax_rate_code = PV_TAX_RATE_CODE;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_cnt   := 0;
                WHEN OTHERS
                THEN
                    l_cnt   := 1;
            END;

            IF l_cnt = 0
            THEN
                SELECT apps.zx_exceptions_s.NEXTVAL
                  INTO l_tax_exception_id
                  FROM DUAL;

                INSERT INTO zx.zx_exceptions (TAX_EXCEPTION_ID,
                                              exception_class_code,
                                              exception_type_code,
                                              tax_regime_code,
                                              tax,
                                              tax_status_code,
                                              tax_rate_code,
                                              content_owner_id,
                                              exception_reason_code,
                                              effective_from,
                                              product_id,
                                              inventory_org_id,
                                              rate_modifier,
                                              TAX_JURISDICTION_ID,
                                              record_type_code,
                                              object_version_number,
                                              duplicate_exception,
                                              CREATED_BY,
                                              CREATION_DATE,
                                              LAST_UPDATED_BY,
                                              LAST_UPDATE_DATE)
                         VALUES (l_tax_exception_id,        --TAX_EXCEPTION_ID
                                 'ITEM',                --exception_class_code
                                 'SPECIAL_RATE',         --exception_type_code
                                 lv_tax_regime_code,        -- tax_regime_code
                                 lv_tax,                               -- tax,
                                 lv_tax_status_code,       -- tax_status_code,
                                 PV_TAX_RATE_CODE,            --tax_rate_code,
                                 PN_CONTENT_OWNER_ID,      --content_owner_id,
                                 PV_EXEMPT_REASON,   -- exception_reason_code,
                                 TO_CHAR (ld_exempt_start_dt, 'DD-MON-YYYY'), --effective_from,
                                 i.inventory_item_id,            --product_id,
                                 PN_MST_INV_ORG,           --inventory_org_id,
                                 0,                           --rate_modifier,
                                 ln_TAX_JURISDICTION_ID, --TAX_JURISDICTION_ID,
                                 'USER',                   --record_type_code,
                                 1,                   --object_version_number,
                                 0,                      --duplicate_exception
                                 apps.fnd_profile.VALUE ('USER_ID'), --CREATED_BY
                                 SYSDATE,                      --CREATION_DATE
                                 apps.fnd_profile.VALUE ('USER_ID'), -- LAST_UPDATED_BY
                                 SYSDATE                    --LAST_UPDATE_DATE
                                        );

                l_count   := l_count + 1;
                apps.FND_FILE.PUT_LINE (apps.FND_FILE.OUTPUT,
                                        'ITEM         :   ' || i.item_number);
            END IF;
        END LOOP;

        COMMIT;

        apps.FND_FILE.PUT_LINE (
            apps.FND_FILE.OUTPUT,
            'Total Number of records inserted    :' || l_count);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            --DBMS_OUTPUT.PUT_LINE('NO DATA FOUND'|| SQLERRM);
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'Program Terminated Abruptly');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'All Data is Not Processed');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG, 'NO_DATA_FOUND');
            PV_ERRBUF    := 'No Data Found' || SQLCODE || SQLERRM;
            PV_RETCODE   := -1;
            ROLLBACK;
        WHEN INVALID_CURSOR
        THEN
            -- DBMS_OUTPUT.PUT_LINE('INVALID CURSOR' || SQLERRM);
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'Program Terminated Abruptly');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'All Data is Not Processed');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG, 'INVALID_CURSOR');
            PV_ERRBUF    := 'Invalid Cursor' || SQLCODE || SQLERRM;
            PV_RETCODE   := -2;
            ROLLBACK;
        WHEN TOO_MANY_ROWS
        THEN
            --    DBMS_OUTPUT.PUT_LINE('TOO MANY ROWS' || SQLERRM);
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'Program Terminated Abruptly');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'All Data is Not Processed');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG, 'TOO_MANY_ROWS');
            PV_ERRBUF    := 'Too Many Rows' || SQLCODE || SQLERRM;
            PV_RETCODE   := -3;
            ROLLBACK;
        WHEN PROGRAM_ERROR
        THEN
            --    DBMS_OUTPUT.PUT_LINE('PROGRAM ERROR' || SQLERRM);
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'Program Terminated Abruptly');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'All Data is Not Processed');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG, 'PROGRAM_ERROR');
            PV_ERRBUF    := 'Program Error' || SQLCODE || SQLERRM;
            PV_RETCODE   := -4;
            ROLLBACK;
        WHEN OTHERS
        THEN
            --    DBMS_OUTPUT.PUT_LINE('OTHERS' || SQLERRM);
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'Program Terminated Abruptly');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'All Data is Not Processed');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG, 'OTHERS');
            PV_ERRBUF    := 'Unhandled Error' || SQLCODE || SQLERRM;
            PV_RETCODE   := -5;
            ROLLBACK;
    END TAX_EXEMPT_ITEMS;
END XXDOOM013_REP_PKG;
/
