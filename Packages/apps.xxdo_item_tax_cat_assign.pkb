--
-- XXDO_ITEM_TAX_CAT_ASSIGN  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:36 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_ITEM_TAX_CAT_ASSIGN"
AS
    /*********************************************************************************************
    * $Header$
    * Program Name : XXDO_ITEM_TAX_CAT_ASSIGN.pkb
    * Language     : PL/SQL
    * Description  : Item Tax Category Assignment
    * History      :
    * WHO            WHAT                                                                    WHEN
    * BT Tech Team      V1.0                                                                3/16/2015
    * Gaurav            1.1 CCR0008031 Item Tax Class Maintenance and Updates to RMS        8/12/2019
    ************************************************************************************************/

    FUNCTION DEFAULT_TAX_CATEGORY_ID (p_tax_category_set_name IN VARCHAR2, p_segment1 IN VARCHAR2, p_segment2 IN VARCHAR2
                                      , p_segment3 IN VARCHAR2, p_segment4 IN VARCHAR2, p_segment5 IN VARCHAR2)
        RETURN NUMBER
    IS
        l_tax_category_id   NUMBER := NULL;
    BEGIN
        FOR i
            IN (  SELECT r.reference, r.segment1, r.segment2,
                         r.segment3, r.segment4, r.segment5,
                         r.default_tax_category, c.category_id
                    FROM do_custom.xxdo_def_item_tax_cat_rules r, apps.mtl_category_sets cs, apps.mtl_categories_b c
                   WHERE     cs.category_set_name = p_tax_category_set_name
                         AND cs.structure_id = c.structure_id
                         AND c.segment1 = r.default_tax_category
                         AND NVL (r.segment1, p_segment1) = p_segment1
                         AND NVL (r.segment2, p_segment2) = p_segment2
                         AND NVL (r.segment3, p_segment3) = p_segment3
                         AND NVL (r.segment4, p_segment4) = p_segment4
                         AND NVL (r.segment5, p_segment5) = p_segment5
                ORDER BY r.reference, r.segment1, r.segment2,
                         r.segment3, r.segment4, r.segment5)
        LOOP
            l_tax_category_id   := i.category_id;
            RETURN (l_tax_category_id);
        END LOOP;

        RETURN (l_tax_category_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN (NULL);
    END;

    PROCEDURE UPDATE_DEFAULT_CATEGORY (p_inv_category_set_name   IN VARCHAR2,
                                       p_tax_category_set_name   IN VARCHAR2)
    IS
        l_tax_category_id     NUMBER;
        l_tax_category_Name   VARCHAR2 (180);
        l_count               NUMBER := 0;
        l_user_id             NUMBER;
    BEGIN
        l_user_id   := FND_PROFILE.VALUE ('USER_ID');
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            '2. Updating Inventory Categories - Default Tax Class (Based on Rules):');
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            '-----------------------------------------------------------------------------------');

        -- Inventory Categories missing default tax category DFF attribute
        FOR c
            IN (--begin CCR0008031 Item Tax Class Maintenance and Updates to RMS ver 1.1-- update dff attribute with correct tax cat where there is a mismatch
                SELECT cat.segment1, cat.segment2, cat.segment3,
                       cat.segment4, cat.segment5, SUBSTR (cat.concatenated_segments, 1, 80) category_combo,
                       cat.category_id, fifs.id_flex_structure_name
                  FROM apps.mtl_categories_kfv cat, apps.mtl_category_sets cs, apps.mtl_categories_b b,
                       apps.fnd_id_flex_structures_vl fifs, do_custom.xxdo_def_item_tax_cat_rules r
                 WHERE     cs.category_set_name = p_inv_category_set_name -- 'Inventory'
                       AND cs.structure_id = cat.structure_id
                       AND cat.structure_id = fifs.id_flex_num
                       AND b.category_id = cat.attribute1
                       AND fifs.application_id = 401
                       AND fifs.id_flex_code = 'MCAT'
                       AND cat.attribute1 IS NOT NULL
                       AND b.segment1 <> default_tax_category -- tax code is different
                       AND (r.segment2) = cat.segment2
                       AND (r.segment3) = cat.segment3
                       AND (r.segment4) = cat.segment4
                       AND (r.segment5) = cat.segment5
                UNION
                -- end CCR0008031 Item Tax Class Maintenance and Updates to RMS CCR# ver 1.1
                SELECT cat.segment1, cat.segment2, cat.segment3,
                       cat.segment4, cat.segment5, SUBSTR (cat.concatenated_segments, 1, 80) category_combo,
                       cat.category_id, fifs.id_flex_structure_name
                  FROM apps.mtl_categories_kfv cat, apps.mtl_category_sets cs, apps.fnd_id_flex_structures_vl fifs
                 WHERE     cs.category_set_name = p_inv_category_set_name -- 'Inventory'
                       AND cs.structure_id = cat.structure_id
                       AND cat.structure_id = fifs.id_flex_num
                       AND fifs.application_id = 401
                       AND fifs.id_flex_code = 'MCAT'
                       AND cat.attribute1 IS NULL
                ORDER BY
                    segment1, segment2, segment3,
                    segment4, segment5)
        LOOP
            -- Derive the default tax category
            l_tax_category_id   :=
                DEFAULT_TAX_CATEGORY_ID (p_tax_category_set_name,
                                         c.segment1,
                                         c.segment2,
                                         c.segment3,
                                         c.segment4,
                                         c.segment5);

            IF     l_tax_category_id IS NOT NULL
               AND l_user_id IS NOT NULL
               AND c.id_flex_structure_name IS NOT NULL
            THEN
                -- Update DFF attribute
                BEGIN
                    UPDATE apps.mtl_categories_b cat
                       SET cat.attribute1 = l_tax_category_id, cat.attribute_category = c.id_flex_structure_name, cat.last_updated_by = l_user_id,
                           cat.last_update_date = SYSDATE
                     WHERE cat.category_id = c.category_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ROLLBACK WORK;
                END;

                COMMIT;

                -- Derive visible category name
                BEGIN
                    SELECT RPAD (cat.segment1, 10, ' ') || ' ' || cd.description
                      INTO l_tax_category_name
                      FROM apps.mtl_categories_b cat, apps.mtl_categories_tl cd
                     WHERE     cat.category_id = l_tax_category_id
                           AND cat.category_id = cd.category_id
                           AND cd.language = USERENV ('LANG');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_tax_category_name   := NULL;
                END;

                -- Output Details to the log file
                IF l_count = 0
                THEN
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                        '   Item Category                                                                    Default Tax Category');
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                        '   -------------------------------------------------------------------------------- ---------------------------------');
                END IF;

                l_count   := l_count + 1;
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       '   '
                    || RPAD (c.category_combo, 80, ' ')
                    || ' '
                    || l_tax_category_name);
            END IF;
        END LOOP;

        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            '   >> ' || TO_CHAR (l_count) || ' record(s) updated.');
        FND_FILE.PUT_LINE (FND_FILE.LOG, '');

        -- Output remaining un-assigned categories to the log file
        l_count     := 0;

        FOR c
            IN (  SELECT cat.segment1, cat.segment2, cat.segment3,
                         cat.segment4, cat.segment5, SUBSTR (cat.concatenated_segments, 1, 80) category_combo,
                         cat.category_id, fifs.id_flex_structure_name
                    FROM apps.mtl_categories_kfv cat, apps.mtl_category_sets cs, apps.fnd_id_flex_structures_vl fifs
                   WHERE     cs.category_set_name = p_inv_category_set_name -- 'Inventory'
                         AND cs.structure_id = cat.structure_id
                         AND cat.structure_id = fifs.id_flex_num
                         AND fifs.application_id = 401
                         AND fifs.id_flex_code = 'MCAT'
                         AND cat.attribute1 IS NULL
                ORDER BY cat.segment1, cat.segment2, cat.segment3,
                         cat.segment4, cat.segment5)
        LOOP
            IF l_count = 0
            THEN
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    '   The following categories still contain no default tax category:');
                FND_FILE.PUT_LINE (FND_FILE.LOG, '   Item Category');
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    '   --------------------------------------------------------------------------------');
            END IF;

            FND_FILE.PUT_LINE (FND_FILE.LOG, '   ' || c.category_combo);
            l_count   := l_count + 1;
        END LOOP;

        IF l_count <> 0
        THEN
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                '   >> ' || TO_CHAR (l_count) || ' record(s) found.');
        END IF;
    END;

    PROCEDURE INSERT_NEW_ITEM_CATEGORIES (p_inv_category_set_name IN VARCHAR2, p_tax_category_set_name IN VARCHAR2, p_master_inv_org_code IN VARCHAR2)
    IS
        l_api_version     NUMBER := 1.0;
        l_return_status   VARCHAR2 (80);
        l_error_code      NUMBER;
        l_msg_count       NUMBER;
        l_msg_data        VARCHAR2 (3000);
        v_msg_data        VARCHAR2 (3000); -- ver 1.1 - tax category assignment
        l_insert_count    NUMBER := 0;
        l_error_count     NUMBER := 0;
    BEGIN
        FND_FILE.PUT_LINE (FND_FILE.LOG, '');
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           '3. Creating New Tax Category Assignments:');
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            '-------------------------------------------------------------------------------');

        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
               '   Tax Category Item Number               '
            || RPAD ('Item Category', 50, ' ')
            || ' Status Status Comments');
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
               '   ------------ '
            || RPAD ('-', 25, '-')
            || ' '
            || RPAD ('-', 50, '-')
            || ' ------ '
            || RPAD ('-', 50, '-'));

        -- Loop on all items in the specified master org and inventory item category assignment
        -- Filter to only those where:
        -- Inventory category as a default tax category
        -- Item is not yet assigned to a tax category (for the specified tax category set)
        FOR i
            IN (  SELECT mic.inventory_item_id, msi.concatenated_segments item_number, mic.organization_id,
                         p.organization_code, c.category_id inv_category_id, c.concatenated_segments inv_category,
                         c.attribute1 tax_category_id, c_tax.concatenated_segments tax_category, cs_tax.category_set_id tax_category_set_id,
                         tax_cat.category_id actual_tax_category_id, tax_cat.category_name actual_tax_category
                    FROM apps.mtl_system_items_kfv msi,
                         apps.mtl_parameters p,
                         apps.mtl_category_sets cs,
                         apps.mtl_categories_kfv c,
                         apps.mtl_item_categories mic,
                         apps.mtl_categories_kfv c_tax,
                         apps.mtl_category_sets cs_tax,
                         (SELECT mic.inventory_item_id, mic.organization_id, c.category_id,
                                 c.concatenated_segments category_name
                            FROM apps.mtl_category_sets cs, apps.mtl_categories_kfv c, apps.mtl_item_categories mic
                           WHERE     cs.category_set_name =
                                     p_tax_category_set_name    -- 'Tax Class'
                                 AND cs.category_set_id = mic.category_set_id
                                 AND mic.category_id = c.category_id
                                 AND cs.structure_id = c.structure_id) tax_cat
                   WHERE     msi.organization_id = p.organization_id
                         AND p.organization_code = p_master_inv_org_code -- 'VNT'
                         AND cs.category_set_name = p_inv_category_set_name -- 'Inventory'
                         AND cs.category_set_id = mic.category_set_id
                         AND msi.inventory_item_id = mic.inventory_item_id
                         AND msi.organization_id = mic.organization_id
                         AND mic.category_id = c.category_id
                         AND cs.structure_id = c.structure_id
                         AND c.attribute1 = c_tax.category_id -- Only include items where the related INVENTORY item category has a related tax category
                         AND cs_tax.category_set_name = p_tax_category_set_name -- 'Tax Class'
                         AND cs_tax.structure_id = c_tax.structure_id
                         AND msi.inventory_item_id =
                             tax_cat.inventory_item_id(+)
                         AND msi.organization_id = tax_cat.organization_id(+)
                         AND tax_cat.category_id IS NULL -- Tax Class category assignment doesn't exist
                --AND      msi.segment1 between '5000' and '5999' -- in ( 'AHNU ITEM-BLK-ALL','AHNU ITEM-BLK-NA')
                ORDER BY tax_category, inv_category, item_number)
        LOOP
            l_error_code      := NULL;
            l_return_status   := NULL;
            l_msg_data        := NULL;
            l_msg_count       := NULL;
            v_msg_data        := NULL;
            --  CCR0008031 Item Tax Class Maintenance and Updates to RMS  ver 1.1 commented begin block
            --  BEGIN
            INV_ITEM_CATEGORY_PUB.CREATE_CATEGORY_ASSIGNMENT (
                p_api_version         => l_api_version,
                --p_init_msg_list     => FALSE,
                --p_commit            => FALSE,
                x_return_status       => l_return_status,
                x_errorcode           => l_error_code,
                x_msg_count           => l_msg_count,
                x_msg_data            => l_msg_data,
                p_category_id         => i.tax_category_id,
                p_category_set_id     => i.tax_category_set_id,
                p_inventory_item_id   => i.inventory_item_id,
                p_organization_id     => i.organization_id);

            -- Begin: CCR0008031 Item Tax Class Maintenance and Updates to RMS  ver 1.1 exception block not required. hence commented
            /*
            EXCEPTION WHEN OTHERS THEN
                l_error_code := 99;
                l_return_status := 'E';
                l_msg_data := substr(SQLERRM,1,3000);
                l_msg_count := 1;
            END;
      */
            --  End: CCR0008031 Item Tax Class Maintenance and Updates to RMS  ver 1.1; exception block not required. hence commented
            --  Begin :CCR0008031 Item Tax Class Maintenance and Updates to RMS  ver 1.1 ; above error handling is not required in a apicall. getting error message using standard API.
            IF l_return_status <> fnd_api.g_ret_sts_success
            THEN
                FOR i IN 1 .. l_msg_count
                LOOP
                    v_msg_data   :=
                        SUBSTR (
                            (v_msg_data || oe_msg_pub.get (p_msg_index => i, p_encoded => 'F')),
                            1,
                            2999);
                END LOOP;
            END IF;

            --  End : CCR0008031 Item Tax Class Maintenance and Updates to RMS  ver 1.1 above error handling is not required in a apicall. getting error message using standard API.
            -- Output results to the log file
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   '   '
                || RPAD (i.tax_category, 12, ' ')
                || ' '
                || RPAD (i.item_number, 25, ' ')
                || ' '
                || RPAD (SUBSTR (i.inv_category, 1, 50), 50, ' ')
                || ' '
                || RPAD (SUBSTR (l_return_status, 1, 6), 6, ' ')
                || ' '
                || v_msg_data);

            IF l_return_status <> 'S'
            THEN
                l_error_count   := l_error_count + 1;
            ELSE
                l_insert_count   := l_insert_count + 1;
            END IF;

            COMMIT;
        END LOOP;

        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            '   >> ' || TO_CHAR (l_insert_count) || ' record(s) inserted.');
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            '   >> ' || TO_CHAR (l_error_count) || ' error record(s) found.');
    END;

    -- Begin CCR0008031 Item Tax Class Maintenance and Updates to RMS ver 1.1

    PROCEDURE update_tax_category_assignment (p_inv_category_set_name IN VARCHAR2, p_tax_category_set_name IN VARCHAR2, p_master_inv_org_code IN VARCHAR2)
    IS
        l_api_version     NUMBER := 1.0;
        l_return_status   VARCHAR2 (80);
        l_error_code      NUMBER;
        l_msg_count       NUMBER;
        l_msg_data        VARCHAR2 (3000);
        v_msg_data        VARCHAR2 (3000);
        l_insert_count    NUMBER := 0;
        l_error_count     NUMBER := 0;
    BEGIN
        FND_FILE.PUT_LINE (FND_FILE.LOG, '');
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           '3. updaing Tax Category Assignments:');
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            '-------------------------------------------------------------------------------');

        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
               'INVENTORY_ITEM_ID'
            || '|'
            || 'ITEM_NUMBER'
            || '|'
            || 'CURRENT_TAX_CATEGORY_ID'
            || '|'
            || 'CURRENT_TAX_CATEGORY_NAME'
            || '|'
            || 'NEW_TAX_CATEGORY_ID'
            || '|'
            || 'NEW_TAX_CAT_NAME'
            || '|'
            || 'STATUS'
            || '|'
            || 'Message');

        -- Loop on all items in the specified master org and inventory item category assignment
        -- Filter to only those where:
        --  tax category exists
        --  Item  has a tax category but doesnt matches with PLM data
        FOR i
            IN (SELECT c_tax.category_id, mic.inventory_item_id, msi.concatenated_segments item_number,
                       mic.organization_id, p.organization_code, c.concatenated_segments inv_category,
                       tax_cat.curr_tax_category_id, curr_tax_category_name, c_tax.category_id shuld_be_tax_category_id,
                       dit.default_tax_category should_be_tax_cat_name, cs_tax.category_set_id tax_category_set_id
                  FROM apps.mtl_system_items_kfv msi,
                       apps.mtl_parameters p,
                       apps.mtl_category_sets cs,
                       apps.mtl_categories_kfv c,
                       apps.mtl_item_categories mic,
                       do_custom.xxdo_def_item_tax_cat_rules dit,
                       apps.mtl_categories_kfv c_tax,
                       apps.mtl_category_sets cs_tax,
                       (SELECT mic.inventory_item_id, mic.organization_id, c.category_id curr_tax_category_id,
                               c.concatenated_segments curr_tax_category_name
                          FROM apps.mtl_category_sets cs, apps.mtl_categories_kfv c, apps.mtl_item_categories mic
                         WHERE     cs.category_set_name = 'Tax Class'
                               AND cs.category_set_id = mic.category_set_id
                               AND mic.category_id = c.category_id
                               AND cs.structure_id = c.structure_id) tax_cat
                 WHERE     1 = 1
                       AND msi.organization_id = p.organization_id
                       AND p.organization_code = 'MST'
                       AND cs.category_set_name = 'Inventory'
                       AND cs.category_set_id = mic.category_set_id
                       AND msi.inventory_item_id = mic.inventory_item_id
                       AND msi.organization_id = mic.organization_id
                       AND mic.category_id = c.category_id
                       AND c.attribute1 = c_tax.category_id
                       AND cs_tax.category_set_name = 'Tax Class'
                       --AND mic.inventory_item_id IN (900010161)
                       AND msi.inventory_item_id = tax_cat.inventory_item_id
                       AND msi.organization_id = tax_cat.organization_id
                       AND cs_tax.structure_id = c_tax.structure_id
                       AND c.segment2 = dit.segment2
                       AND c.segment3 = dit.segment3
                       AND c.segment4 = dit.segment4
                       AND c.segment5 = dit.segment5
                       AND tax_cat.curr_tax_category_id IS NOT NULL
                       AND dit.default_tax_category <>
                           tax_cat.curr_tax_category_name
                       AND EXISTS -- THIS CONDITION WILL INGORE INVAID TAX CODE THAT DOESNT EVEN EXSITS IN EBS BUT THERE IN THE CUSTOM TABLE
                               (SELECT 1
                                  FROM apps.mtl_category_sets a, apps.mtl_categories_B b
                                 WHERE     1 = 1
                                       AND a.category_set_name = 'Tax Class'
                                       AND a.structure_id = b.structure_id
                                       AND b.segment1 =
                                           dit.default_tax_category))
        LOOP
            l_error_code      := NULL;
            l_return_status   := NULL;
            l_msg_data        := NULL;
            l_msg_count       := NULL;
            v_msg_data        := NULL;

            INV_ITEM_CATEGORY_PUB.update_CATEGORY_ASSIGNMENT (
                p_api_version         => l_api_version,
                x_return_status       => l_return_status,
                x_errorcode           => l_error_code,
                x_msg_count           => l_msg_count,
                x_msg_data            => l_msg_data,
                p_old_category_id     => i.curr_tax_category_id,
                p_category_id         => i.shuld_be_tax_category_id,
                p_category_set_id     => i.tax_category_set_id,
                p_inventory_item_id   => i.inventory_item_id,
                p_organization_id     => i.organization_id);

            IF l_return_status <> fnd_api.g_ret_sts_success
            THEN
                FOR i IN 1 .. l_msg_count
                LOOP
                    v_msg_data   :=
                        SUBSTR (
                            (v_msg_data || ' ' || oe_msg_pub.get (p_msg_index => i, p_encoded => 'F')),
                            1,
                            2999);
                END LOOP;
            END IF;

            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   i.INVENTORY_ITEM_ID
                || '|'
                || i.ITEM_NUMBER
                || '|'
                || i.CURr_TAX_CATEGORY_ID
                || '|'
                || i.CURR_TAX_CATEGORY_NAME
                || '|'
                || i.SHULD_BE_TAX_CATEGORY_ID
                || '|'
                || i.should_be_tax_cat_name
                || '|'
                || l_return_status
                || '|'
                || v_msg_data);

            IF l_return_status <> 'S'
            THEN
                l_error_count   := l_error_count + 1;
            ELSE
                l_insert_count   := l_insert_count + 1;
            END IF;

            COMMIT;
        END LOOP;

        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            '   >> ' || TO_CHAR (l_insert_count) || ' record(s) updated.');
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            '   >> ' || TO_CHAR (l_error_count) || ' error record(s) found.');
    END;

    -- CCR0008031 Item Tax Class Maintenance and Updates to RMS End ver 1.1
    PROCEDURE MAIN (ERRBUF                       OUT VARCHAR2,
                    RETCODE                      OUT VARCHAR2,
                    p_inv_category_set_name   IN     VARCHAR2,
                    p_tax_category_set_name   IN     VARCHAR2,
                    p_master_inv_org_code     IN     VARCHAR2)
    IS
        l_inv_category_set_id     NUMBER;
        l_inv_category_set_name   VARCHAR2 (80) := p_inv_category_set_name;
        l_tax_category_set_id     NUMBER;
        l_tax_category_set_name   VARCHAR2 (80) := p_tax_category_set_name;
        l_master_inv_org_id       NUMBER;
        l_master_inv_org_code     VARCHAR2 (30) := p_master_inv_org_code;
        l_user_id                 NUMBER;
        l_user_name               VARCHAR2 (80);
    BEGIN
        -- 1. Validate parameters before continuing
        -- 1.1.Validate p_inv_category_set_name
        BEGIN
            SELECT structure_id
              INTO l_inv_category_set_id
              FROM apps.mtl_category_sets
             WHERE category_set_name = l_inv_category_set_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_inv_category_set_id   := NULL;
        END;

        -- 1.2.Validate p_tax_category_set_name
        BEGIN
            SELECT structure_id
              INTO l_tax_category_set_id
              FROM apps.mtl_category_sets
             WHERE category_set_name = l_tax_category_set_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_tax_category_set_id   := NULL;
        END;

        -- 1.3.Validate p_master_inv_org_code
        BEGIN
            SELECT organization_id
              INTO l_master_inv_org_id
              FROM apps.mtl_parameters
             WHERE     organization_code = p_master_inv_org_code
                   AND organization_id = master_organization_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_master_inv_org_id   := NULL;
        END;

        -- 1.4 Derive current User_id
        l_user_id   := FND_PROFILE.VALUE ('USER_ID');

        BEGIN
            SELECT user_name
              INTO l_user_name
              FROM apps.fnd_user
             WHERE user_id = l_user_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_user_name   := NULL;
        END;

        FND_FILE.PUT_LINE (FND_FILE.LOG, '1. Parameters:');
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            '-------------------------------------------------------------------------------');
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
               '   Inventory Category Set:  '
            || RPAD (l_inv_category_set_name, 30, ' ')
            || ' ('
            || TO_CHAR (l_inv_category_set_id)
            || ')');
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
               '   Tax Category Set:        '
            || RPAD (l_tax_category_set_name, 30, ' ')
            || ' ('
            || TO_CHAR (l_tax_category_set_id)
            || ')');
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
               '   Master Inventory Org:    '
            || RPAD (l_master_inv_org_code, 30, ' ')
            || ' ('
            || TO_CHAR (l_master_inv_org_id)
            || ')');
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
               '   User:                    '
            || RPAD (l_user_name, 30, ' ')
            || ' ('
            || TO_CHAR (l_user_id)
            || ')');
        FND_FILE.PUT_LINE (FND_FILE.LOG, '');

        IF    l_inv_category_set_id IS NULL
           OR l_tax_category_set_id IS NULL
           OR l_master_inv_org_id IS NULL
           OR l_user_id IS NULL
        THEN
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                '   ERROR: One or more invalid parameters - Exiting...');
            RETURN;
        END IF;

        -- 2. Update Inventory Categories with the default Tax category (where it is missing)
        update_default_category (l_inv_category_set_name,
                                 l_tax_category_set_name);

        -- 3. Create new Item Tax Category assignments for items missing - based on Item defaults.
        insert_new_item_categories (l_inv_category_set_name,
                                    l_tax_category_set_name,
                                    l_master_inv_org_code);

        --4. BEGIN Changes: 1.1:  check and update tax category assignment if doesnt match with plm staging table;
        IF     l_inv_category_set_name = 'Inventory'
           AND l_tax_category_set_name = 'Tax Class'
        THEN
            update_tax_category_assignment (l_inv_category_set_name,
                                            l_tax_category_set_name,
                                            l_master_inv_org_code);
        END IF;
    --  End   Changes: 1.1:  update tax category assignment if doesnt match with plm

    END;
END;
/
