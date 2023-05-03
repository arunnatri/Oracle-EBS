--
-- XXD_PROD_LINE_CAT_CNV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:24 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXD_PROD_LINE_CAT_CNV_PKG
AS
    -- +==============================================================================+
    -- +                        Oracle 12i                                            +
    -- +==============================================================================+
    -- |                                                                              |
    -- |Object Name :   XXD_PROD_LINE_CAT_CNV_PKG                                    |
    -- |Description   : The package  is defined to assign the                        |
    -- |                default production line category to all the items in R12      |
    -- |                                                           |
    -- |                                                                              |
    -- |Usage:                                                                        |
    -- |                                                                              |
    -- |                                                                              |
    -- |                                                                              |
    -- |Change Record:                                                                |
    -- |===============                                                               |
    -- |Version   Date             Author             Remarks                              |
    -- |=======   ==========  ===================   ============================      |
    -- |1.0       26-MAY-2015  BT Technology Team     Initial draft version           |
    -- +==============================================================================+
    PROCEDURE print_msg_prc (p_debug VARCHAR2, p_message IN VARCHAR2)
    AS
    BEGIN
        IF p_debug = 'Y'
        THEN
            FND_FILE.put_line (FND_FILE.LOG, p_message);
            DBMS_OUTPUT.put_line (p_message);
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            FND_FILE.put_line (FND_FILE.LOG, SQLERRM);
        WHEN OTHERS
        THEN
            FND_FILE.put_line (FND_FILE.LOG, SQLERRM);
    END print_msg_prc;

    PROCEDURE extract_cat_to_stg (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, p_inv_org_id IN NUMBER)
    AS
        CURSOR c_cat_main IS
            SELECT segment1 item_number, inventory_item_id, organization_id,
                   'PRODUCTION_LINE' category_set_name, 'ADI' segment1, 'ES' segment2,
                   'TOTHER' segment3, NULL segment4
              FROM mtl_system_items_b
             WHERE organization_id = NVL (p_inv_org_id, organization_id);


        TYPE c_main_type IS TABLE OF c_cat_main%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_main_tab      c_main_type;


        ld_date          DATE;
        ln_total_count   NUMBER;
        ln_count         NUMBER;
    BEGIN
        --Extract Process starts here

        DELETE FROM XXD_INV_PROD_LINE_CAT_STG_T;

        COMMIT;

        SELECT SYSDATE INTO ld_date FROM SYS.DUAL;

        print_msg_prc (p_debug     => gc_debug_flag,
                       p_message   => 'Procedure extract_main');

        OPEN c_cat_main;

        LOOP
            FETCH c_cat_main BULK COLLECT INTO lt_main_tab LIMIT 20000;

            EXIT WHEN lt_main_tab.COUNT = 0;

            FORALL i IN 1 .. lt_main_tab.COUNT
                --Inserting to Staging Table XXD_INV_PROD_LINE_CAT_STG_T
                INSERT INTO XXD_INV_PROD_LINE_CAT_STG_T (RECORD_ID, BATCH_NUMBER, RECORD_STATUS, ITEM_NUMBER, inventory_item_id, ORGANIZATION_ID, CATEGORY_SET_NAME, SEGMENT1, SEGMENT2, SEGMENT3, SEGMENT4, CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE
                                                         , ERROR_MESSAGE)
                     VALUES (XXD_CONV.XXD_INV_ITEM_CATEGORY_STG_S.NEXTVAL, NULL, 'N', lt_main_tab (i).ITEM_NUMBER, lt_main_tab (i).inventory_item_id, lt_main_tab (i).ORGANIZATION_ID, lt_main_tab (i).CATEGORY_SET_NAME, lt_main_tab (i).SEGMENT1, lt_main_tab (i).SEGMENT2, lt_main_tab (i).SEGMENT3, lt_main_tab (i).SEGMENT4, fnd_global.user_id, ld_date, fnd_global.login_id, ld_date
                             , NULL);


            ln_total_count   := ln_total_count + ln_count;
            ln_count         := ln_count + 1;

            IF ln_total_count = 20000
            THEN
                ln_total_count   := 0;
                ln_count         := 0;
                COMMIT;
            END IF;
        END LOOP;

        CLOSE c_cat_main;

        print_msg_prc (
            p_debug     => gc_debug_flag,
            p_message   => 'End Time:' || TO_CHAR (SYSDATE, 'hh:mi:ss'));
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_msg_prc (p_debug     => gc_debug_flag,
                           p_message   => 'error mesg:' || SQLERRM);
            NULL;
    END extract_cat_to_stg;

    FUNCTION validate_valueset_value (p_category_set_name IN VARCHAR2, p_application_column_name IN VARCHAR2, p_flex_value IN VARCHAR2
                                      , p_flex_desc IN VARCHAR2)
        RETURN VARCHAR2
    AS
        x_rowid                VARCHAR2 (1000);
        ln_flex_value_id       NUMBER := 0;
        ln_flex_value_set_id   NUMBER := 0;
    BEGIN
        print_msg_prc (
            p_debug   => gc_debug_flag,
            p_message   =>
                   'validate_valueset_value for '
                || p_application_column_name
                || ' and value '
                || p_flex_value);

        BEGIN
            SELECT ffs.flex_value_set_id, mcs.category_set_id
              INTO ln_flex_value_set_id, gn_category_set_id
              FROM fnd_id_flex_segments ffs, mtl_category_sets_v mcs
             WHERE     application_id = 401
                   AND id_flex_code = 'MCAT'
                   AND id_flex_num = mcs.structure_id
                   AND ffs.enabled_flag = 'Y'
                   AND mcs.category_set_name = p_category_set_name
                   AND application_column_name = p_application_column_name;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_flex_value_set_id   := 0;
            WHEN OTHERS
            THEN
                ln_flex_value_set_id   := 0;
        END;

        IF ln_flex_value_set_id > 0
        THEN
            BEGIN
                SELECT FLEX_VALUE_ID
                  INTO ln_flex_value_id
                  FROM fnd_flex_values ffs
                 WHERE     ln_flex_value_set_id = ffs.flex_value_set_id
                       AND flex_value = p_flex_value;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_flex_value_id   := 0;
                WHEN OTHERS
                THEN
                    ln_flex_value_id   := 0;
            END;
        END IF;

        RETURN 'S';
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            gn_record_error_flag   := 1;
            print_msg_prc (p_debug => gc_debug_flag, p_message => SQLERRM);
            RETURN 'E';
        WHEN OTHERS
        THEN
            gn_record_error_flag   := 1;
            print_msg_prc (p_debug => gc_debug_flag, p_message => SQLERRM);
            RETURN 'E';
    END validate_valueset_value;

    PROCEDURE get_category_id (p_batch_number IN NUMBER, p_processing_row_id IN NUMBER, x_return_status OUT VARCHAR2)
    AS
        l_category_rec      inv_item_category_pub.category_rec_type;
        l_category_set_id   mtl_category_sets_v.category_set_id%TYPE;
        l_segment_array     FND_FLEX_EXT.SegmentArray;
        l_n_segments        NUMBER := 0;
        l_delim             VARCHAR2 (1000);
        l_success           BOOLEAN;
        l_concat_segs       VARCHAR2 (32000);
        l_return_status     VARCHAR2 (80);
        l_error_code        NUMBER;
        l_msg_count         NUMBER;
        l_msg_data          VARCHAR2 (32000);
        l_messages          VARCHAR2 (32000) := '';
        l_out_category_id   NUMBER;
        x_message_list      error_handler.error_tbl_type;
        x_msg_data          VARCHAR2 (32000);
        l_seg_description   VARCHAR2 (32000);


        CURSOR get_segments (l_structure_id NUMBER)
        IS
              SELECT application_column_name, ROWNUM
                FROM fnd_id_flex_segments
               WHERE     application_id = 401
                     AND id_flex_code = 'MCAT'
                     AND id_flex_num = l_structure_id
                     AND enabled_flag = 'Y'
            ORDER BY segment_num ASC;

        CURSOR get_structure_id (cp_category_set_name VARCHAR2)
        IS
            SELECT structure_id, category_set_id
              FROM mtl_category_sets_v
             WHERE category_set_name = cp_category_set_name;

        CURSOR get_category_id (cp_structure_id        NUMBER,
                                cp_concatenated_segs   VARCHAR2)
        IS
            SELECT category_id
              FROM mtl_categories_b_kfv
             WHERE     structure_id = cp_structure_id
                   AND concatenated_segments =
                       REPLACE (cp_concatenated_segs, '\.', '.');
    BEGIN
        print_msg_prc (p_debug     => gc_debug_flag,
                       p_message   => 'create_category');
        l_return_status   := FND_API.G_RET_STS_SUCCESS;

        FOR lc_cat_data
            IN (SELECT *
                  FROM XXD_INV_PROD_LINE_CAT_STG_T
                 WHERE     batch_number = p_batch_number
                       AND record_id = p_processing_row_id)
        LOOP
            gn_category_id               := NULL;
            l_category_rec.SEGMENT1      := NULL;
            l_category_rec.SEGMENT2      := NULL;
            l_category_rec.SEGMENT3      := NULL;
            l_category_rec.SEGMENT4      := NULL;
            l_category_rec.SEGMENT5      := NULL;
            l_category_rec.SEGMENT6      := NULL;
            l_category_rec.SEGMENT7      := NULL;
            l_category_rec.SEGMENT8      := NULL;
            l_category_rec.SEGMENT9      := NULL;
            l_category_rec.SEGMENT10     := NULL;
            l_category_rec.SEGMENT11     := NULL;
            l_category_rec.SEGMENT12     := NULL;
            l_category_rec.SEGMENT13     := NULL;
            l_category_rec.SEGMENT14     := NULL;
            l_category_rec.SEGMENT15     := NULL;
            l_category_rec.SEGMENT16     := NULL;
            l_category_rec.SEGMENT17     := NULL;
            l_category_rec.SEGMENT18     := NULL;
            l_category_rec.SEGMENT19     := NULL;
            l_category_rec.SEGMENT20     := NULL;
            FND_MSG_PUB.Initialize;

            OPEN get_structure_id (
                cp_category_set_name => lc_cat_data.category_set_name);

            FETCH get_structure_id INTO l_category_rec.structure_id, l_category_set_id;

            CLOSE get_structure_id;


            gn_category_set_id           := l_category_set_id;

            l_seg_description            := NULL;
            gn_category_id               := NULL;

            FOR c_segments IN get_segments (l_category_rec.structure_id)
            LOOP
                l_n_segments   := c_segments.ROWNUM;

                IF c_segments.application_column_name = 'SEGMENT1'
                THEN
                    l_category_rec.SEGMENT1   := lc_cat_data.SEGMENT1;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.SEGMENT1;
                ELSIF c_segments.application_column_name = 'SEGMENT2'
                THEN
                    l_category_rec.SEGMENT2   := lc_cat_data.SEGMENT2;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.SEGMENT2;
                ELSIF c_segments.application_column_name = 'SEGMENT3'
                THEN
                    l_category_rec.SEGMENT3   := lc_cat_data.SEGMENT3;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.SEGMENT3;
                ELSIF c_segments.application_column_name = 'SEGMENT4'
                THEN
                    l_category_rec.SEGMENT4   := lc_cat_data.SEGMENT4;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.SEGMENT4;
                ELSIF c_segments.application_column_name = 'SEGMENT5'
                THEN
                    l_category_rec.SEGMENT5   := lc_cat_data.SEGMENT5;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.SEGMENT5;
                ELSIF c_segments.application_column_name = 'SEGMENT6'
                THEN
                    l_category_rec.SEGMENT6   := lc_cat_data.SEGMENT6;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.SEGMENT6;
                ELSIF c_segments.application_column_name = 'SEGMENT7'
                THEN
                    l_category_rec.SEGMENT7   := lc_cat_data.SEGMENT7;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.SEGMENT7;
                ELSIF c_segments.application_column_name = 'SEGMENT8'
                THEN
                    l_category_rec.SEGMENT8   := lc_cat_data.SEGMENT8;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.SEGMENT8;
                ELSIF c_segments.application_column_name = 'SEGMENT9'
                THEN
                    l_category_rec.SEGMENT9   := lc_cat_data.SEGMENT9;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.SEGMENT9;
                ELSIF c_segments.application_column_name = 'SEGMENT10'
                THEN
                    l_category_rec.SEGMENT10   := lc_cat_data.SEGMENT10;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.SEGMENT10;
                ELSIF c_segments.application_column_name = 'SEGMENT11'
                THEN
                    l_category_rec.SEGMENT11   := lc_cat_data.SEGMENT11;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.SEGMENT11;
                ELSIF c_segments.application_column_name = 'SEGMENT12'
                THEN
                    l_category_rec.SEGMENT12   := lc_cat_data.SEGMENT12;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.SEGMENT12;
                ELSIF c_segments.application_column_name = 'SEGMENT13'
                THEN
                    l_category_rec.SEGMENT13   := lc_cat_data.SEGMENT13;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.SEGMENT13;
                ELSIF c_segments.application_column_name = 'SEGMENT14'
                THEN
                    l_category_rec.SEGMENT14   := lc_cat_data.SEGMENT14;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.SEGMENT14;
                ELSIF c_segments.application_column_name = 'SEGMENT15'
                THEN
                    l_category_rec.SEGMENT15   := lc_cat_data.SEGMENT15;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.SEGMENT15;
                ELSIF c_segments.application_column_name = 'SEGMENT16'
                THEN
                    l_category_rec.SEGMENT16   := lc_cat_data.SEGMENT16;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.SEGMENT16;
                ELSIF c_segments.application_column_name = 'SEGMENT17'
                THEN
                    l_category_rec.SEGMENT17   := lc_cat_data.SEGMENT17;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.SEGMENT17;
                ELSIF c_segments.application_column_name = 'SEGMENT18'
                THEN
                    l_category_rec.SEGMENT18   := lc_cat_data.SEGMENT18;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.SEGMENT18;
                ELSIF c_segments.application_column_name = 'SEGMENT19'
                THEN
                    l_category_rec.SEGMENT19   := lc_cat_data.SEGMENT19;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.SEGMENT19;
                ELSIF c_segments.application_column_name = 'SEGMENT20'
                THEN
                    l_category_rec.SEGMENT20   := lc_cat_data.SEGMENT20;
                    l_segment_array (c_segments.ROWNUM)   :=
                        lc_cat_data.SEGMENT20;
                END IF;
            END LOOP;


            l_delim                      :=
                fnd_flex_ext.get_delimiter ('INV',
                                            'MCAT',
                                            l_category_rec.structure_id);

            l_concat_segs                :=
                fnd_flex_ext.concatenate_segments (l_n_segments,
                                                   l_segment_array,
                                                   l_delim);
            l_success                    :=
                fnd_flex_keyval.validate_segs (
                    operation          => 'FIND_COMBINATION',
                    appl_short_name    => 'INV',
                    key_flex_code      => 'MCAT',
                    structure_number   => l_category_rec.structure_id,
                    concat_segments    => l_concat_segs);
            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'OPEN get_category_id structure_id  => '
                    || l_category_rec.structure_id);
            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'OPEN get_category_id l_concat_segs  => '
                    || l_concat_segs);

            l_category_rec.description   := l_concat_segs;

            OPEN get_category_id (l_category_rec.structure_id, l_concat_segs);

            FETCH get_category_id INTO gn_category_id;

            CLOSE get_category_id;

            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'OPEN get_category_id gn_category_id  => '
                    || gn_category_id);

            IF (NOT l_success) AND gn_category_id IS NULL
            THEN
                print_msg_prc (
                    p_debug     => gc_debug_flag,
                    p_message   => 'OPEN get_category_id l_success  => True');
                FND_MSG_PUB.Initialize;
                inv_item_category_pub.create_category (
                    p_api_version     => 1.0,
                    p_init_msg_list   => fnd_api.g_false,
                    p_commit          => fnd_api.g_false,
                    x_return_status   => l_return_status,
                    x_errorcode       => l_error_code,
                    x_msg_count       => l_msg_count,
                    x_msg_data        => l_msg_data,
                    p_category_rec    => l_category_rec,
                    x_category_id     => l_out_category_id);

                IF (l_return_status = FND_API.G_RET_STS_SUCCESS)
                THEN
                    gn_category_id   := l_out_category_id;
                    print_msg_prc (gc_debug_flag,
                                   'Category Id: ' || gn_category_id);
                ELSE
                    gn_category_id   := NULL;
                END IF;

                IF (l_return_status <> FND_API.G_RET_STS_SUCCESS)
                THEN
                    FND_MSG_PUB.COUNT_AND_GET (p_encoded   => 'F',
                                               p_count     => l_msg_count,
                                               p_data      => l_msg_data);

                    FOR K IN 1 .. l_msg_count
                    LOOP
                        l_messages   :=
                               l_messages
                            || fnd_msg_pub.get (p_msg_index   => k,
                                                p_encoded     => 'F')
                            || ';';
                        print_msg_prc (
                            p_debug     => gc_debug_flag,
                            p_message   => 'l_messages => ' || l_messages);
                    END LOOP;

                    FND_MESSAGE.SET_NAME ('FND', 'GENERIC-INTERNAL ERROR');
                    FND_MESSAGE.SET_TOKEN ('ROUTINE', 'Category Migration');
                    FND_MESSAGE.SET_TOKEN ('REASON', l_messages);

                    print_msg_prc (p_debug     => gc_debug_flag,
                                   p_message   => FND_MESSAGE.GET);
                    xxd_common_utils.record_error (
                        p_module       => 'INV',
                        p_org_id       => gn_org_id,
                        p_program      =>
                            'Deckers Production Line Category Assignment Conversion',
                        p_error_line   => SQLCODE,
                        p_error_msg    => l_messages,
                        p_created_by   => gn_user_id,
                        p_request_id   => gn_conc_request_id,
                        p_more_info1   => 'GN_INVENTORY_ITEM',
                        p_more_info2   => gn_inventory_item,
                        p_more_info3   => 'CONCAT_SEGS',
                        p_more_info4   => l_concat_segs);
                END IF;
            ELSE
                print_msg_prc (
                    p_debug     => gc_debug_flag,
                    p_message   => 'OPEN get_category_id l_success  => False');

                OPEN get_category_id (l_category_rec.structure_id,
                                      l_concat_segs);

                FETCH get_category_id INTO gn_category_id;

                CLOSE get_category_id;
            END IF;

            x_return_status              := l_return_status;
        END LOOP;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            l_messages   := SQLERRM;
            xxd_common_utils.record_error (
                p_module       => 'INV',
                p_org_id       => gn_org_id,
                p_program      =>
                    'Deckers Production Line Category Conversion Program',
                p_error_line   => SQLCODE,
                p_error_msg    => l_messages,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'GN_INVENTORY_ITEM',
                p_more_info2   => gn_inventory_item,
                p_more_info3   => 'CONCAT_SEGS',
                p_more_info4   => l_concat_segs);
        WHEN OTHERS
        THEN
            l_messages   := SQLERRM;
            xxd_common_utils.record_error (
                p_module       => 'INV',
                p_org_id       => gn_org_id,
                p_program      =>
                    'Deckers Production Line Category Conversion Program',
                p_error_line   => SQLCODE,
                p_error_msg    => l_messages,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'GN_INVENTORY_ITEM',
                p_more_info2   => gn_inventory_item,
                p_more_info3   => 'CONCAT_SEGS',
                p_more_info4   => l_concat_segs);
    END get_category_id;

    PROCEDURE inv_category_validation (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY NUMBER, p_batch_number IN NUMBER)
    /**********************************************************************************************
    *                                                                                             *
    * Function  Name       :  inv_category_validation                                             *
    *                                                                                             *
    * Description          :  Procedure to perform all the required validations                   *
    *                                                                                             *
    * Called From          :                                                                      *
    *                                                                                             *
    *  Change History                                                                             *
    *  -----------------                                                                          *
    *  Version    Date             Author                Description                              *
    *  ---------  ------------    ---------------       -----------------------------             *
    *   1.0       26-MAY-2015  BT Technology Team     Initial draft version                       *
    *                                                                                             *
    **********************************************************************************************/
    IS
        CURSOR cur_item_category (p_batch_number NUMBER)
        IS
            SELECT *
              FROM XXD_INV_PROD_LINE_CAT_STG_T
             WHERE     RECORD_STATUS IN (gc_new_status, gc_error_status)
                   AND batch_number = p_batch_number;

        lc_err_msg              VARCHAR2 (2000) := NULL;
        x_return_status         VARCHAR2 (10) := NULL;
        l_category_set_exists   VARCHAR2 (10);
        l_old_category_id       NUMBER;
        l_segment_exists        VARCHAR2 (1);
    BEGIN
        print_msg_prc (gc_debug_flag,
                       'Working on Batch    => ' || p_batch_number);

        OPEN cur_item_category (p_batch_number => p_batch_number);

        LOOP
            FETCH cur_item_category
                BULK COLLECT INTO gt_item_cat_rec
                LIMIT 50;

            EXIT WHEN gt_item_cat_rec.COUNT = 0;

            print_msg_prc (gc_debug_flag,
                           'validate Order header ' || gt_item_cat_rec.COUNT);

            IF gt_item_cat_rec.COUNT > 0
            THEN
                -- Check if there are any records in the staging table that need to be processed
                FOR lc_item_cat_idx IN 1 .. gt_item_cat_rec.COUNT
                LOOP
                    gn_organization_id        := NULL;
                    gn_inventory_item_id      := NULL;
                    gn_category_id            := NULL;
                    gn_category_set_id        := NULL;
                    gc_err_msg                := NULL;
                    gc_stg_tbl_process_flag   := NULL;
                    gn_record_error_flag      := 0;
                    lc_err_msg                := NULL;
                    gn_inventory_item         :=
                        gt_item_cat_rec (lc_item_cat_idx).item_number;
                    x_return_status           := fnd_api.g_ret_sts_success;
                    l_segment_exists          := 'Y';

                    -- Check if the mandatory field Organization code exists or not and validate the organization code
                    print_msg_prc (
                        gc_debug_flag,
                        'gn_record_error_flag    => ' || gn_record_error_flag);


                    ---- Validate value set values in Segments.
                    print_msg_prc (gc_debug_flag,
                                   'Validate value set values in Segments.');

                    IF gt_item_cat_rec (lc_item_cat_idx).segment1 IS NOT NULL
                    THEN
                        x_return_status   :=
                            validate_valueset_value (
                                p_category_set_name         =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_application_column_name   => 'SEGMENT1',
                                p_flex_value                =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment1,
                                p_flex_desc                 =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment1_desc);

                        IF x_return_status = 'E'
                        THEN
                            l_segment_exists   := 'N';
                            lc_err_msg         :=
                                   'SEGMENT1 '
                                || gt_item_cat_rec (lc_item_cat_idx).segment1
                                || ' Not defind in Category Set '
                                || gt_item_cat_rec (lc_item_cat_idx).category_set_name;

                            xxd_common_utils.record_error (
                                p_module       => 'INV',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers Production Line Category Assignment Conversion',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_err_msg,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_more_info2   =>
                                    gt_item_cat_rec (lc_item_cat_idx).item_number,
                                p_more_info3   => 'SEGMENT1',
                                p_more_info4   =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment1);
                        END IF;
                    -- ELSE
                    --gn_record_error_flag := 1;
                    END IF;

                    print_msg_prc (
                        gc_debug_flag,
                           'Validate value set values in Segment2.'
                        || gn_record_error_flag);

                    IF gt_item_cat_rec (lc_item_cat_idx).segment2 IS NOT NULL
                    THEN
                        x_return_status   := fnd_api.g_ret_sts_success;
                        x_return_status   :=
                            validate_valueset_value (
                                p_category_set_name         =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_application_column_name   => 'SEGMENT2',
                                p_flex_value                =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment2,
                                p_flex_desc                 =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment2_desc);

                        IF x_return_status = 'E'
                        THEN
                            l_segment_exists   := 'N';
                            lc_err_msg         :=
                                   'SEGMENT2 '
                                || gt_item_cat_rec (lc_item_cat_idx).SEGMENT2
                                || ' Not defind in Category Set '
                                || gt_item_cat_rec (lc_item_cat_idx).category_set_name;

                            xxd_common_utils.record_error (
                                p_module       => 'INV',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers Production Line Category Assignment Conversion',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_err_msg,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_more_info2   =>
                                    gt_item_cat_rec (lc_item_cat_idx).item_number,
                                p_more_info3   => 'SEGMENT2',
                                p_more_info4   =>
                                    gt_item_cat_rec (lc_item_cat_idx).SEGMENT2);
                        END IF;
                    --                     ELSE
                    --                     gn_record_error_flag := 1;
                    END IF;

                    print_msg_prc (
                        gc_debug_flag,
                           'Validate value set values in Segment3.'
                        || gn_record_error_flag);

                    IF gt_item_cat_rec (lc_item_cat_idx).segment3 IS NOT NULL
                    THEN
                        x_return_status   := fnd_api.g_ret_sts_success;
                        x_return_status   :=
                            validate_valueset_value (
                                p_category_set_name         =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_application_column_name   => 'SEGMENT3',
                                p_flex_value                =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment3,
                                p_flex_desc                 =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment3_desc);

                        IF x_return_status = 'E'
                        THEN
                            l_segment_exists   := 'N';
                            lc_err_msg         :=
                                   'SEGMENT3 '
                                || gt_item_cat_rec (lc_item_cat_idx).SEGMENT3
                                || ' Not defind in Category Set '
                                || gt_item_cat_rec (lc_item_cat_idx).category_set_name;

                            xxd_common_utils.record_error (
                                p_module       => 'INV',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers Production Line Category Assignment Conversion',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_err_msg,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_more_info2   =>
                                    gt_item_cat_rec (lc_item_cat_idx).item_number,
                                p_more_info3   => 'SEGMENT3',
                                p_more_info4   =>
                                    gt_item_cat_rec (lc_item_cat_idx).SEGMENT3);
                        END IF;
                    END IF;

                    print_msg_prc (
                        gc_debug_flag,
                           'Validate value set values in Segment4.'
                        || gn_record_error_flag);

                    IF gt_item_cat_rec (lc_item_cat_idx).segment4 IS NOT NULL
                    THEN
                        x_return_status   := fnd_api.g_ret_sts_success;
                        x_return_status   :=
                            validate_valueset_value (
                                p_category_set_name         =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_application_column_name   => 'SEGMENT4',
                                p_flex_value                =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment4,
                                p_flex_desc                 =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment4_desc);

                        IF x_return_status = 'E'
                        THEN
                            l_segment_exists   := 'N';
                            lc_err_msg         :=
                                   'SEGMENT4 '
                                || gt_item_cat_rec (lc_item_cat_idx).SEGMENT4
                                || ' Not defind in Category Set '
                                || gt_item_cat_rec (lc_item_cat_idx).category_set_name;

                            xxd_common_utils.record_error (
                                p_module       => 'INV',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers Production Line Category Assignment Conversion',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_err_msg,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_more_info2   =>
                                    gt_item_cat_rec (lc_item_cat_idx).item_number,
                                p_more_info3   => 'SEGMENT4',
                                p_more_info4   =>
                                    gt_item_cat_rec (lc_item_cat_idx).SEGMENT4);
                        END IF;
                    END IF;

                    print_msg_prc (
                        gc_debug_flag,
                           'Validate value set values in Segment5.'
                        || gn_record_error_flag);

                    IF gt_item_cat_rec (lc_item_cat_idx).segment5 IS NOT NULL
                    THEN
                        x_return_status   := fnd_api.g_ret_sts_success;
                        x_return_status   :=
                            validate_valueset_value (
                                p_category_set_name         =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_application_column_name   => 'SEGMENT5',
                                p_flex_value                =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment5,
                                p_flex_desc                 =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment5_desc);

                        IF x_return_status = 'E'
                        THEN
                            l_segment_exists   := 'N';
                            lc_err_msg         :=
                                   'SEGMENT5 '
                                || gt_item_cat_rec (lc_item_cat_idx).SEGMENT5
                                || ' Not defind in Category Set '
                                || gt_item_cat_rec (lc_item_cat_idx).category_set_name;

                            xxd_common_utils.record_error (
                                p_module       => 'INV',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers Production Line Category Assignment Conversion',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_err_msg,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_more_info2   =>
                                    gt_item_cat_rec (lc_item_cat_idx).item_number,
                                p_more_info3   => 'SEGMENT5',
                                p_more_info4   =>
                                    gt_item_cat_rec (lc_item_cat_idx).SEGMENT5);
                        END IF;
                    END IF;

                    IF gt_item_cat_rec (lc_item_cat_idx).segment6 IS NOT NULL
                    THEN
                        x_return_status   := fnd_api.g_ret_sts_success;
                        x_return_status   :=
                            validate_valueset_value (
                                p_category_set_name         =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_application_column_name   => 'SEGMENT6',
                                p_flex_value                =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment6,
                                p_flex_desc                 =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment6_desc);

                        IF x_return_status = 'E'
                        THEN
                            l_segment_exists   := 'N';
                            lc_err_msg         :=
                                   'SEGMENT6 '
                                || gt_item_cat_rec (lc_item_cat_idx).SEGMENT6
                                || ' Not defind in Category Set '
                                || gt_item_cat_rec (lc_item_cat_idx).category_set_name;

                            xxd_common_utils.record_error (
                                p_module       => 'INV',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers Production Line Category Assignment Conversion',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_err_msg,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_more_info2   =>
                                    gt_item_cat_rec (lc_item_cat_idx).item_number,
                                p_more_info3   => 'SEGMENT6',
                                p_more_info4   =>
                                    gt_item_cat_rec (lc_item_cat_idx).SEGMENT6);
                        END IF;
                    END IF;

                    IF gt_item_cat_rec (lc_item_cat_idx).segment7 IS NOT NULL
                    THEN
                        x_return_status   := fnd_api.g_ret_sts_success;
                        x_return_status   :=
                            validate_valueset_value (
                                p_category_set_name         =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_application_column_name   => 'SEGMENT7',
                                p_flex_value                =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment7,
                                p_flex_desc                 =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment7_desc);

                        IF x_return_status = 'E'
                        THEN
                            l_segment_exists   := 'N';
                            lc_err_msg         :=
                                   'SEGMENT7 '
                                || gt_item_cat_rec (lc_item_cat_idx).SEGMENT7
                                || ' Not defind in Category Set '
                                || gt_item_cat_rec (lc_item_cat_idx).category_set_name;

                            xxd_common_utils.record_error (
                                p_module       => 'INV',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers Production Line Category Assignment Conversion',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_err_msg,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_more_info2   =>
                                    gt_item_cat_rec (lc_item_cat_idx).item_number,
                                p_more_info3   => 'SEGMENT7',
                                p_more_info4   =>
                                    gt_item_cat_rec (lc_item_cat_idx).SEGMENT7);
                        END IF;
                    END IF;

                    IF gt_item_cat_rec (lc_item_cat_idx).segment8 IS NOT NULL
                    THEN
                        x_return_status   := fnd_api.g_ret_sts_success;
                        x_return_status   :=
                            validate_valueset_value (
                                p_category_set_name         =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_application_column_name   => 'SEGMENT8',
                                p_flex_value                =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment8,
                                p_flex_desc                 =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment8_desc);

                        IF x_return_status = 'E'
                        THEN
                            l_segment_exists   := 'N';
                            lc_err_msg         :=
                                   'SEGMENT8 '
                                || gt_item_cat_rec (lc_item_cat_idx).SEGMENT8
                                || ' Not defind in Category Set '
                                || gt_item_cat_rec (lc_item_cat_idx).category_set_name;

                            xxd_common_utils.record_error (
                                p_module       => 'INV',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers Production Line Category Assignment Conversion',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_err_msg,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_more_info2   =>
                                    gt_item_cat_rec (lc_item_cat_idx).item_number,
                                p_more_info3   => 'SEGMENT8',
                                p_more_info4   =>
                                    gt_item_cat_rec (lc_item_cat_idx).SEGMENT8);
                        END IF;
                    END IF;

                    print_msg_prc (
                        gc_debug_flag,
                           'Validate value set values in Segment9.'
                        || gn_record_error_flag);

                    IF gt_item_cat_rec (lc_item_cat_idx).segment9 IS NOT NULL
                    THEN
                        x_return_status   := fnd_api.g_ret_sts_success;
                        x_return_status   :=
                            validate_valueset_value (
                                p_category_set_name         =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_application_column_name   => 'SEGMENT9',
                                p_flex_value                =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment9,
                                p_flex_desc                 =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment9_desc);

                        IF x_return_status = 'E'
                        THEN
                            l_segment_exists   := 'N';
                            lc_err_msg         :=
                                   'SEGMENT9 '
                                || gt_item_cat_rec (lc_item_cat_idx).segment9
                                || ' Not defind in Category Set '
                                || gt_item_cat_rec (lc_item_cat_idx).category_set_name;

                            xxd_common_utils.record_error (
                                p_module       => 'INV',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers Production Line Category Assignment Conversion',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_err_msg,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   =>
                                    gt_item_cat_rec (lc_item_cat_idx).category_set_name,
                                p_more_info2   =>
                                    gt_item_cat_rec (lc_item_cat_idx).item_number,
                                p_more_info3   => 'SEGMENT9',
                                p_more_info4   =>
                                    gt_item_cat_rec (lc_item_cat_idx).segment9);
                        END IF;
                    END IF;


                    print_msg_prc (
                        gc_debug_flag,
                        'x_return_status         =>' || x_return_status);
                    print_msg_prc (
                        gc_debug_flag,
                        'l_segment_exists         =>' || l_segment_exists);
                    print_msg_prc (
                        gc_debug_flag,
                        'gn_record_error_flag    =>' || gn_record_error_flag);
                    print_msg_prc (
                        gc_debug_flag,
                           'p_batch_number                =>'
                        || gt_item_cat_rec (lc_item_cat_idx).batch_number);
                    print_msg_prc (
                        gc_debug_flag,
                           'record_id       =>'
                        || gt_item_cat_rec (lc_item_cat_idx).record_id);

                    IF l_segment_exists <> 'N'
                    THEN
                        UPDATE XXD_INV_PROD_LINE_CAT_STG_T
                           SET RECORD_STATUS   = gc_validate_status
                         WHERE     batch_number =
                                   gt_item_cat_rec (lc_item_cat_idx).batch_number
                               AND record_id =
                                   gt_item_cat_rec (lc_item_cat_idx).record_id;
                    ELSE
                        UPDATE XXD_INV_PROD_LINE_CAT_STG_T
                           SET RECORD_STATUS   = gc_error_status
                         WHERE     batch_number =
                                   gt_item_cat_rec (lc_item_cat_idx).batch_number
                               AND record_id =
                                   gt_item_cat_rec (lc_item_cat_idx).record_id;
                    END IF;
                END LOOP;
            END IF;

            COMMIT;
        END LOOP;

        CLOSE cur_item_category;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
            errbuf    := SQLERRM;
            retcode   := 2;
            lc_err_msg   :=
                   'Unexpected error while cursor fetching into PL/SQL table - '
                || SQLERRM;
            print_msg_prc (gc_debug_flag, lc_err_msg);
            xxd_common_utils.record_error (
                p_module       => 'INV',
                p_org_id       => gn_org_id,
                p_program      =>
                    'Deckers Production Line Category Assignment Conversion',
                p_error_line   => SQLCODE,
                p_error_msg    => lc_err_msg,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => NULL);
    END inv_category_validation;

    --Start Modification by BT Technology Team v1.1 on 10-MAY-2015
    PROCEDURE create_us_category_assignment (
        p_category_id         IN     NUMBER,
        p_category_set_id     IN     NUMBER,
        p_inventory_item_id   IN     NUMBER,
        p_organization_id     IN     NUMBER,
        x_return_status          OUT VARCHAR2)
    AS
        lx_return_status   NUMBER;
        x_error_message    VARCHAR2 (2000);

        x_msg_data         VARCHAR2 (2000);
        li_msg_count       NUMBER;
        ls_msg_data        VARCHAR2 (4000);
        l_messages         VARCHAR2 (4000);
        li_error_code      NUMBER;
        x_message_list     error_handler.error_tbl_type;
        ln_rec_cnt         NUMBER := 0;

        CURSOR us_org_cur IS
            SELECT organization_id, organization_code
              FROM mtl_parameters
             WHERE organization_code LIKE 'US%';
    BEGIN
        print_msg_prc (p_debug     => gc_debug_flag,
                       p_message   => ' 1 create_us_category_assignment');
        x_return_status   := 'S';
        print_msg_prc (
            p_debug     => gc_debug_flag,
            p_message   => 'Message gn_inventory_item:' || gn_inventory_item);
        print_msg_prc (
            p_debug   => gc_debug_flag,
            p_message   =>
                'Message p_inventory_item_id:' || p_inventory_item_id);
        print_msg_prc (
            p_debug     => gc_debug_flag,
            p_message   => 'Message p_category_set_id:' || p_category_set_id);
        print_msg_prc (
            p_debug     => gc_debug_flag,
            p_message   => 'Message p_category_id:' || p_category_id);

        FOR us_org_rec IN us_org_cur
        LOOP
            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                    'Message us_org_rec.organization_id:' || us_org_rec.organization_id);

            SELECT COUNT (1)
              INTO ln_rec_cnt
              FROM mtl_system_items_b
             WHERE     inventory_item_id = p_inventory_item_id
                   AND organization_id = us_org_rec.organization_id;

            IF ln_rec_cnt = 0
            THEN
                x_return_status   := 'E';
                xxd_common_utils.record_error (
                    p_module       => 'INV',
                    p_org_id       => gn_org_id,
                    p_program      =>
                        'Deckers Production Line Category Assignment Conversion',
                    p_error_line   => SQLCODE,
                    p_error_msg    =>
                        'Item and Organization Id combination does not exist.',
                    p_created_by   => gn_user_id,
                    p_request_id   => gn_conc_request_id,
                    p_more_info1   => gn_inventory_item,
                    p_more_info2   => us_org_rec.organization_code,
                    p_more_info3   => p_category_id,
                    p_more_info4   => p_category_set_id);
            ELSE
                SELECT COUNT (1)
                  INTO ln_rec_cnt
                  FROM mtl_item_categories
                 WHERE     inventory_item_id = p_inventory_item_id
                       AND organization_id = us_org_rec.organization_id
                       AND category_set_id = p_category_set_id
                       AND category_id = p_category_id;

                print_msg_prc (
                    p_debug     => gc_debug_flag,
                    p_message   => 'Message ln_rec_cnt:' || ln_rec_cnt);

                IF ln_rec_cnt = 0
                THEN
                    print_msg_prc (
                        p_debug     => gc_debug_flag,
                        p_message   => 'Call create_category_assignment:');
                    fnd_msg_pub.delete_msg ();
                    inv_item_category_pub.create_category_assignment (
                        p_api_version         => 1,
                        p_init_msg_list       => fnd_api.g_false,
                        p_commit              => fnd_api.g_false,
                        x_return_status       => x_return_status,
                        x_errorcode           => li_error_code,
                        x_msg_count           => li_msg_count,
                        x_msg_data            => ls_msg_data,
                        p_category_id         => p_category_id,
                        p_category_set_id     => p_category_set_id,
                        p_inventory_item_id   => p_inventory_item_id,
                        p_organization_id     => us_org_rec.organization_id);


                    print_msg_prc (
                        p_debug     => gc_debug_flag,
                        p_message   => 'Message Count:' || x_message_list.COUNT);
                    print_msg_prc (
                        p_debug     => gc_debug_flag,
                        p_message   => 'Status :' || x_return_status);

                    IF x_return_status <> fnd_api.g_ret_sts_success
                    THEN
                        fnd_msg_pub.count_and_get (
                            p_encoded   => 'F',
                            p_count     => li_msg_count,
                            p_data      => ls_msg_data);

                        print_msg_prc (
                            p_debug     => gc_debug_flag,
                            p_message   => 'Err Message:' || ls_msg_data);

                        FOR k IN 1 .. li_msg_count
                        LOOP
                            l_messages   :=
                                   l_messages
                                || fnd_msg_pub.get (p_msg_index   => k,
                                                    p_encoded     => 'F')
                                || ';';
                            print_msg_prc (
                                p_debug   => gc_debug_flag,
                                p_message   =>
                                       'l_messages => '
                                    || k
                                    || '-'
                                    || l_messages);
                        END LOOP;

                        IF l_messages IS NULL
                        THEN
                            l_messages   :=
                                   'An item '
                                || p_inventory_item_id
                                || ' can be assigned to only one category within this category set.';
                        END IF;

                        xxd_common_utils.record_error (
                            p_module       => 'INV',
                            p_org_id       => gn_org_id,
                            p_program      =>
                                'Deckers Production Line Category Assignment Conversion',
                            p_error_line   => SQLCODE,
                            p_error_msg    =>
                                NVL (
                                    SUBSTR (l_messages, 2000),
                                    'Error in create_us_category_assignment'),
                            p_created_by   => gn_user_id,
                            p_request_id   => gn_conc_request_id,
                            p_more_info1   => gn_inventory_item,
                            p_more_info2   => 'p_category_id',
                            p_more_info3   => p_category_id,
                            p_more_info4   => p_category_set_id);
                    END IF;
                END IF;
            END IF;
        END LOOP;

        print_msg_prc (p_debug     => gc_debug_flag,
                       p_message   => ' 1 status is 2:' || x_return_status);
        print_msg_prc (
            p_debug   => gc_debug_flag,
            p_message   =>
                ' 1 Processing category  Status ' || x_return_status);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            print_msg_prc (
                p_debug     => gc_debug_flag,
                p_message   => 'Err in create Assignment:' || SQLERRM);
            l_messages   := SQLERRM;

            xxd_common_utils.record_error (
                p_module       => 'INV',
                p_org_id       => gn_org_id,
                p_program      =>
                    'Deckers Production Line Category Assignment Conversion',
                p_error_line   => SQLCODE,
                p_error_msg    =>
                    NVL (SUBSTR (l_messages, 2000),
                         'Error in create_us_category_assignment'),
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => gn_inventory_item,
                p_more_info2   => 'p_category_id',
                p_more_info3   => p_category_id,
                p_more_info4   => p_category_set_id);
        WHEN OTHERS
        THEN
            print_msg_prc (
                p_debug     => gc_debug_flag,
                p_message   => 'Err in create Assignment:' || SQLERRM);
            l_messages   := SQLERRM;
            xxd_common_utils.record_error (
                p_module       => 'INV',
                p_org_id       => gn_org_id,
                p_program      =>
                    'Deckers Production Line Category Assignment Conversion',
                p_error_line   => SQLCODE,
                p_error_msg    =>
                    NVL (SUBSTR (l_messages, 2000),
                         'Error in create_us_category_assignment'),
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => gn_inventory_item,
                p_more_info2   => 'p_category_id',
                p_more_info3   => p_category_id,
                p_more_info4   => p_category_set_id);
    END create_us_category_assignment;

    --End Modification by BT Technology Team v1.1 on 10-MAY-2015

    PROCEDURE create_category_assignment (
        p_category_id         IN     NUMBER,
        p_category_set_id     IN     NUMBER,
        p_inventory_item_id   IN     NUMBER,
        p_organization_id     IN     NUMBER,
        x_return_status          OUT VARCHAR2)
    AS
        lx_return_status   NUMBER;
        x_error_message    VARCHAR2 (2000);
        --x_return_status       VARCHAR2 (10);
        x_msg_data         VARCHAR2 (2000);
        li_msg_count       NUMBER;
        ls_msg_data        VARCHAR2 (4000);
        l_messages         VARCHAR2 (4000);
        li_error_code      NUMBER;
        x_message_list     error_handler.error_tbl_type;
        ln_rec_cnt         NUMBER := 0;
    BEGIN
        print_msg_prc (p_debug     => gc_debug_flag,
                       p_message   => 'create_category_assignment');

        SELECT COUNT (1)
          INTO ln_rec_cnt
          FROM mtl_item_categories
         WHERE     INVENTORY_ITEM_ID = p_inventory_item_id
               AND ORGANIZATION_ID = p_organization_id
               AND CATEGORY_SET_ID = p_category_set_id
               AND CATEGORY_ID = p_category_id;

        IF ln_rec_cnt = 0
        THEN
            inv_item_category_pub.create_category_assignment (
                p_api_version         => 1,
                p_init_msg_list       => fnd_api.g_false,
                p_commit              => fnd_api.g_false,
                x_return_status       => x_return_status,
                x_errorcode           => li_error_code,
                x_msg_count           => li_msg_count,
                x_msg_data            => ls_msg_data,
                p_category_id         => p_category_id,
                p_category_set_id     => p_category_set_id,
                p_inventory_item_id   => p_inventory_item_id,
                p_organization_id     => p_organization_id);

            --  error_handler.get_message_list (x_message_list => x_message_list);

            IF x_return_status <> fnd_api.g_ret_sts_success
            THEN
                print_msg_prc (
                    p_debug     => gc_debug_flag,
                    p_message   => 'status is count:' || x_message_list.COUNT);
                print_msg_prc (
                    p_debug     => gc_debug_flag,
                    p_message   => 'status is 1:' || x_return_status);

                FND_MSG_PUB.COUNT_AND_GET (p_encoded   => 'F',
                                           p_count     => li_msg_count,
                                           p_data      => ls_msg_data);

                print_msg_prc (
                    p_debug     => gc_debug_flag,
                    p_message   => 'status is ls_msg_data 1:' || ls_msg_data);

                FOR K IN 1 .. li_msg_count
                LOOP
                    l_messages   :=
                           l_messages
                        || fnd_msg_pub.get (p_msg_index => k, p_encoded => 'F')
                        || ';';
                    print_msg_prc (
                        p_debug     => gc_debug_flag,
                        p_message   => 'l_messages => ' || l_messages);
                    fnd_msg_pub.Delete_Msg (k);
                END LOOP;

                IF l_messages IS NULL
                THEN
                    l_messages   :=
                           'An item '
                        || gn_inventory_item
                        || ' can be assigned to only one category within this category set.';
                END IF;

                xxd_common_utils.record_error (
                    p_module       => 'INV',
                    p_org_id       => gn_org_id,
                    p_program      =>
                        'Deckers Production Line Category Assignment Conversion',
                    p_error_line   => SQLCODE,
                    p_error_msg    =>
                        NVL (SUBSTR (l_messages, 2000),
                             'Error in create_category_assignment'),
                    p_created_by   => gn_user_id,
                    p_request_id   => gn_conc_request_id,
                    p_more_info1   => gn_inventory_item,
                    p_more_info2   => 'p_category_id',
                    p_more_info3   => p_category_id,
                    p_more_info4   => p_category_set_id);
            END IF;
        ELSE
            x_return_status   := fnd_api.G_RET_STS_ERROR;
            l_messages        :=
                   'An item '
                || gn_inventory_item
                || ' can be assigned to only one category within this category set.';
            xxd_common_utils.record_error (
                p_module       => 'INV',
                p_org_id       => gn_org_id,
                p_program      =>
                    'Deckers Production Line Category Assignment Conversion',
                p_error_line   => SQLCODE,
                p_error_msg    =>
                    NVL (SUBSTR (l_messages, 2000),
                         'Error in create_category_assignment'),
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => gn_inventory_item,
                p_more_info2   => 'p_category_id',
                p_more_info3   => p_category_id,
                p_more_info4   => p_category_set_id);
        END IF;                                                --ln_rec_cnt >0

        print_msg_prc (p_debug     => gc_debug_flag,
                       p_message   => 'status is 2:' || x_return_status);
        print_msg_prc (
            p_debug     => gc_debug_flag,
            p_message   => 'Processing category  Status ' || x_return_status);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            l_messages   := SQLERRM;

            xxd_common_utils.record_error (
                p_module       => 'INV',
                p_org_id       => gn_org_id,
                p_program      =>
                    'Deckers Production Line Category Assignment Conversion',
                p_error_line   => SQLCODE,
                p_error_msg    =>
                    NVL (SUBSTR (l_messages, 2000),
                         'Error in create_category_assignment'),
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => gn_inventory_item,
                p_more_info2   => 'p_category_id',
                p_more_info3   => p_category_id,
                p_more_info4   => p_category_set_id);
        WHEN OTHERS
        THEN
            l_messages   := SQLERRM;
            xxd_common_utils.record_error (
                p_module       => 'INV',
                p_org_id       => gn_org_id,
                p_program      =>
                    'Deckers Production Line Category Assignment Conversion',
                p_error_line   => SQLCODE,
                p_error_msg    =>
                    NVL (SUBSTR (l_messages, 2000),
                         'Error in create_category_assignment'),
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => gn_inventory_item,
                p_more_info2   => 'p_category_id',
                p_more_info3   => p_category_id,
                p_more_info4   => p_category_set_id);
    END create_category_assignment;

    PROCEDURE update_category_assignment (p_category_id MTL_CATEGORIES_B.category_id%TYPE, p_old_category_id MTL_CATEGORIES_B.category_id%TYPE, p_category_set_id MTL_CATEGORY_SETS_TL.category_set_id%TYPE
                                          , p_inventory_item_id MTL_SYSTEM_ITEMS_B.inventory_item_id%TYPE, p_organization_id MTL_PARAMETERS.organization_id%TYPE, x_return_status OUT VARCHAR2)
    AS
        -- lx_return_status      NUMBER;
        x_error_message   VARCHAR2 (2000);
        --x_return_status       VARCHAR2 (10);
        x_msg_data        VARCHAR2 (2000);
        li_msg_count      NUMBER;
        ls_msg_data       VARCHAR2 (4000);
        l_messages        VARCHAR2 (4000);
        li_error_code     NUMBER;
        x_message_list    error_handler.error_tbl_type;
    BEGIN
        print_msg_prc (p_debug     => gc_debug_flag,
                       p_message   => 'update_category_assignment');

        inv_item_category_pub.update_category_assignment (
            p_api_version         => 1.0,
            p_init_msg_list       => fnd_api.g_false,
            p_commit              => fnd_api.g_false,
            p_category_id         => p_category_id,
            p_old_category_id     => p_old_category_id,
            p_category_set_id     => p_category_set_id,
            p_inventory_item_id   => p_inventory_item_id,
            p_organization_id     => p_organization_id,
            x_return_status       => x_return_status,
            x_errorcode           => li_error_code,
            x_msg_count           => li_msg_count,
            x_msg_data            => x_msg_data);

        IF (x_return_status <> fnd_api.g_ret_sts_success)
        THEN
            error_handler.get_message_list (x_message_list => x_message_list);
            l_messages   := NULL;

            FOR i IN 1 .. x_message_list.COUNT
            LOOP
                IF l_messages IS NULL
                THEN
                    l_messages   := x_message_list (i).MESSAGE_TEXT;
                ELSE
                    l_messages   :=
                        l_messages || ' ' || x_message_list (i).MESSAGE_TEXT;
                END IF;

                fnd_msg_pub.Delete_Msg (i);
            END LOOP;

            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'Error Messages (Update Item Category Assignment):'
                    || l_messages);
            xxd_common_utils.record_error (
                p_module       => 'INV',
                p_org_id       => gn_org_id,
                p_program      =>
                    'Deckers Production Line Category Assignment Conversion',
                p_error_line   => SQLCODE,
                p_error_msg    =>
                    NVL (SUBSTR (l_messages, 2000),
                         'Error in create_category_assignment'),
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'UPDATE_CATEGORY_ASSIGNMENT',
                p_more_info2   => gn_inventory_item,
                p_more_info3   => p_category_id,
                p_more_info4   => p_category_set_id);
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            l_messages   := SQLERRM;

            xxd_common_utils.record_error (
                p_module       => 'INV',
                p_org_id       => gn_org_id,
                p_program      =>
                    'Deckers Production Line Category Assignment Conversion',
                p_error_line   => SQLCODE,
                p_error_msg    =>
                    NVL (SUBSTR (l_messages, 2000),
                         'Error in create_category_assignment'),
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'UPDATE_CATEGORY_ASSIGNMENT',
                p_more_info2   => gn_inventory_item,
                p_more_info3   => p_category_id,
                p_more_info4   => p_category_set_id);
        WHEN OTHERS
        THEN
            l_messages   := SQLERRM;
            xxd_common_utils.record_error (
                p_module       => 'INV',
                p_org_id       => gn_org_id,
                p_program      =>
                    'Deckers Production Line Category Assignment Conversion',
                p_error_line   => SQLCODE,
                p_error_msg    =>
                    NVL (SUBSTR (l_messages, 2000),
                         'Error in create_category_assignment'),
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'UPDATE_CATEGORY_ASSIGNMENT',
                p_more_info2   => gn_inventory_item,
                p_more_info3   => p_category_id,
                p_more_info4   => p_category_set_id);
    END update_category_assignment;

    PROCEDURE inv_category_load (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY NUMBER, p_batch_number IN NUMBER)
    /**********************************************************************************************
    *                                                                                             *
    * Procedure  Name      :  inv_category_load                                                   *
    *                                                                                             *
    * Description          :  Procedure to perform all the required validations                   *
    *                                                                                             *
    * Called From          :                                                                      *
    *                                                                                             *
    *  Change History                                                                             *
    *  -----------------                                                                          *
    *  Version    Date             Author                Description                              *
    *  ---------  ------------    ---------------       -----------------------------             *
    *  1.0       26-MAY-2015  BT Technology Team     Initial draft version                        *
    *                                                                                             *
    **********************************************************************************************/
    IS
        CURSOR cur_item_category (p_batch_number NUMBER)
        IS
            SELECT *
              FROM XXD_INV_PROD_LINE_CAT_STG_T
             WHERE     RECORD_STATUS = gc_validate_status
                   AND batch_number = p_batch_number;


        CURSOR get_structure_id (cp_category_set_name VARCHAR2)
        IS
            SELECT category_set_id
              FROM mtl_category_sets_v
             WHERE category_set_name = cp_category_set_name;


        lc_err_msg              VARCHAR2 (2000) := NULL;
        x_return_status         VARCHAR2 (10) := NULL;
        l_category_set_exists   VARCHAR2 (10);
        l_old_category_id       NUMBER;
        l_segment_exists        VARCHAR2 (1);
        gn_organization_code    VARCHAR2 (30);
    BEGIN
        print_msg_prc (gc_debug_flag,
                       'Working on Batch    => ' || p_batch_number);

        OPEN cur_item_category (p_batch_number => p_batch_number);

        LOOP
            FETCH cur_item_category
                BULK COLLECT INTO gt_item_cat_rec
                LIMIT 50;

            EXIT WHEN gt_item_cat_rec.COUNT = 0;


            print_msg_prc (gc_debug_flag,
                           'validate Order header ' || gt_item_cat_rec.COUNT);

            IF gt_item_cat_rec.COUNT > 0
            THEN
                -- Check if there are any records in the staging table that need to be processed
                FOR lc_item_cat_idx IN 1 .. gt_item_cat_rec.COUNT
                LOOP
                    gn_organization_id        := NULL;
                    gn_inventory_item_id      := NULL;
                    gn_category_id            := NULL;
                    gn_category_set_id        := NULL;
                    gc_err_msg                := NULL;
                    gc_stg_tbl_process_flag   := NULL;
                    gn_record_error_flag      := 0;

                    gn_inventory_item         :=
                        gt_item_cat_rec (lc_item_cat_idx).item_number;
                    x_return_status           := fnd_api.g_ret_sts_success;
                    l_segment_exists          := 'Y';



                    get_category_id (
                        p_batch_number    =>
                            gt_item_cat_rec (lc_item_cat_idx).batch_number,
                        p_processing_row_id   =>
                            gt_item_cat_rec (lc_item_cat_idx).record_id,
                        x_return_status   => x_return_status);


                    OPEN get_structure_id (
                        cp_category_set_name   =>
                            gt_item_cat_rec (lc_item_cat_idx).category_set_name);

                    FETCH get_structure_id INTO gn_category_set_id;

                    CLOSE get_structure_id;

                    IF gn_category_id IS NULL
                    THEN
                        gn_record_error_flag   := 1;
                    ELSE
                        gn_organization_id   :=
                            gt_item_cat_rec (lc_item_cat_idx).organization_id;


                        gn_inventory_item_id   :=
                            gt_item_cat_rec (lc_item_cat_idx).inventory_item_id;
                        print_msg_prc (
                            gc_debug_flag,
                               'gn_inventory_item_id    => '
                            || gn_inventory_item_id);
                        print_msg_prc (
                            gc_debug_flag,
                            'gn_organization_id    => ' || gn_organization_id);
                        print_msg_prc (
                            gc_debug_flag,
                            'gn_category_set_id    => ' || gn_category_set_id);

                        BEGIN
                            SELECT category_id, 'Y'
                              INTO l_old_category_id, l_category_set_exists
                              FROM mtl_item_categories
                             WHERE     inventory_item_id =
                                       gn_inventory_item_id
                                   AND organization_id = gn_organization_id
                                   AND category_set_id = gn_category_set_id;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                l_category_set_exists   := 'N';
                            WHEN OTHERS
                            THEN
                                l_category_set_exists   := 'N';
                        END;

                        print_msg_prc (
                            gc_debug_flag,
                            'gn_category_id    => ' || gn_category_id);

                        IF l_category_set_exists = 'N'
                        THEN
                            create_category_assignment (
                                p_category_id         => gn_category_id,
                                p_category_set_id     => gn_category_set_id,
                                p_inventory_item_id   => gn_inventory_item_id,
                                p_organization_id     => gn_organization_id,
                                x_return_status       => x_return_status);
                        ELSE
                            update_category_assignment (
                                p_category_id         => gn_category_id,
                                p_old_category_id     => l_old_category_id,
                                p_category_set_id     => gn_category_set_id,
                                p_inventory_item_id   => gn_inventory_item_id,
                                p_organization_id     => gn_organization_id,
                                x_return_status       => x_return_status);
                        END IF;
                    END IF;


                    print_msg_prc (
                        gc_debug_flag,
                        'x_return_status         =>' || x_return_status);
                    print_msg_prc (
                        gc_debug_flag,
                        'gn_record_error_flag    =>' || gn_record_error_flag);
                    print_msg_prc (
                        gc_debug_flag,
                           'p_batch_number                =>'
                        || gt_item_cat_rec (lc_item_cat_idx).batch_number);
                    print_msg_prc (
                        gc_debug_flag,
                           'record_id       =>'
                        || gt_item_cat_rec (lc_item_cat_idx).record_id);

                    IF x_return_status = 'S'
                    THEN
                        UPDATE XXD_INV_PROD_LINE_CAT_STG_T
                           SET RECORD_STATUS   = gc_process_status
                         WHERE     batch_number =
                                   gt_item_cat_rec (lc_item_cat_idx).batch_number
                               AND record_id =
                                   gt_item_cat_rec (lc_item_cat_idx).record_id;
                    ELSE
                        UPDATE XXD_INV_PROD_LINE_CAT_STG_T
                           SET RECORD_STATUS   = gc_error_status
                         WHERE     batch_number =
                                   gt_item_cat_rec (lc_item_cat_idx).batch_number
                               AND record_id =
                                   gt_item_cat_rec (lc_item_cat_idx).record_id;
                    END IF;
                END LOOP;
            END IF;

            COMMIT;
        END LOOP;

        CLOSE cur_item_category;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
            errbuf    := SQLERRM;
            retcode   := 2;
            lc_err_msg   :=
                   'Unexpected error while cursor fetching into PL/SQL table - '
                || SQLERRM;
            print_msg_prc (gc_debug_flag, lc_err_msg);
            xxd_common_utils.record_error (
                p_module       => 'INV',
                p_org_id       => gn_org_id,
                p_program      =>
                    'Deckers Production Line Category Assignment Conversion',
                p_error_line   => SQLCODE,
                p_error_msg    => lc_err_msg,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => NULL);
    END inv_category_load;

    --+=====================================================================================+
    -- |Procedure  :  customer_child                                                       |
    -- |                                                                                    |
    -- |Description:  This procedure is the Child Process which will validate and create the|
    -- |              Price list in QP 1223 instance                                        |
    -- |                                                                                    |
    -- | Parameters : p_batch_id, p_action                                                  |
    -- |              p_debug_flag, p_parent_req_id                                         |
    -- |                                                                                    |
    -- |                                                                                    |
    -- | Returns :     x_errbuf,  x_retcode                                                 |
    -- |                                                                                    |
    --+=====================================================================================+

    --Deckers AR Customer Conversion Program (Worker)
    PROCEDURE inv_category_child (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_debug_flag IN VARCHAR2 DEFAULT 'N'
                                  , p_action IN VARCHAR2, p_batch_number IN NUMBER, p_parent_request_id IN NUMBER)
    AS
        le_invalid_param    EXCEPTION;
        ln_new_ou_id        hr_operating_units.organization_id%TYPE; --:= fnd_profile.value('ORG_ID');
        -- This is required in release 12 R12

        ln_request_id       NUMBER := 0;
        lc_username         fnd_user.user_name%TYPE;
        lc_operating_unit   hr_operating_units.NAME%TYPE;
        lc_cust_num         VARCHAR2 (5);
        lc_pri_flag         VARCHAR2 (1);
        ld_start_date       DATE;
        ln_ins              NUMBER := 0;
        --      lc_create_reciprocal_flag   VARCHAR2 (1) := lc_err_msg;
        --ln_request_id             NUMBER                     := 0;
        lc_phase            VARCHAR2 (200);
        lc_status           VARCHAR2 (200);
        lc_delc_phase       VARCHAR2 (200);
        lc_delc_status      VARCHAR2 (200);
        lc_message          VARCHAR2 (200);
        ln_ret_code         NUMBER;
        lc_err_buff         VARCHAR2 (1000);
        ln_count            NUMBER;
        l_target_org_id     NUMBER;
        l_user_id           NUMBER := -1;
        l_resp_id           NUMBER := -1;
        l_application_id    NUMBER := -1;
    BEGIN
        gc_debug_flag        := p_debug_flag;
        gn_conc_request_id   := p_parent_request_id;


        l_user_id            := fnd_global.user_id;



        BEGIN
            SELECT NAME
              INTO lc_operating_unit
              FROM hr_operating_units
             WHERE organization_id = fnd_profile.VALUE ('ORG_ID');
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_operating_unit   := NULL;
        END;



        -- Validation Process for Price List Import
        fnd_file.put_line (
            fnd_file.LOG,
            '*************************************************************************** ');
        fnd_file.put_line (
            fnd_file.LOG,
               '***************     '
            || lc_operating_unit
            || '***************** ');
        fnd_file.put_line (
            fnd_file.LOG,
            '*************************************************************************** ');
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Busines Unit:'
            || lc_operating_unit);
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Run Date    :'
            || TO_CHAR (gd_sys_date, 'DD-MON-YYYY HH24:MI:SS'));
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Request ID  :'
            || fnd_global.conc_request_id);
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Batch ID    :'
            || p_batch_number);
        fnd_file.new_line (fnd_file.LOG, 1);

        fnd_file.new_line (fnd_file.LOG, 1);
        fnd_file.new_line (fnd_file.LOG, 1);
        print_msg_prc (
            gc_debug_flag,
            '+---------------------------------------------------------------------------+');
        print_msg_prc (gc_debug_flag,
                       '******** START of Sales Order Program ******');
        print_msg_prc (
            gc_debug_flag,
            '+---------------------------------------------------------------------------+');

        gc_debug_flag        := p_debug_flag;


        IF p_action = gc_validate_only
        THEN
            print_msg_prc (gc_debug_flag,
                           'Calling inv_category_validation :');

            inv_category_validation (errbuf           => ERRBUF,
                                     retcode          => RETCODE,
                                     p_batch_number   => p_batch_number);
        ELSIF p_action = gc_load_only
        THEN
            inv_category_load (errbuf           => ERRBUF,
                               retcode          => RETCODE,
                               p_batch_number   => p_batch_number);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.output,
                'Exception Raised During Production Line Category assignment Program');
            RETCODE   := 2;
            ERRBUF    := ERRBUF || SQLERRM;
    END inv_category_child;

    PROCEDURE inv_category_main (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY NUMBER, p_Process IN VARCHAR2
                                 , p_batch_size IN NUMBER, p_debug IN VARCHAR2, p_inv_org IN NUMBER)
    IS
        ln_new_rec_count          NUMBER;
        ln_err_rec_count          NUMBER;
        ln_validated_rec_count    NUMBER;
        ln_interfaced_rec_count   NUMBER;
        ln_success_rec_count      NUMBER;
        ln_total_rec_count        NUMBER;
        lc_conlc_status           VARCHAR2 (150);
        ln_request_id             NUMBER := 0;
        lc_phase                  VARCHAR2 (200);
        lc_status                 VARCHAR2 (200);
        lc_dev_phase              VARCHAR2 (200);
        lc_dev_status             VARCHAR2 (200);
        lc_message                VARCHAR2 (200);
        ln_ret_code               NUMBER;
        lc_err_buff               VARCHAR2 (1000);
        ln_count                  NUMBER;
        ln_cntr                   NUMBER := 0;
        ln_parent_request_id      NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
        lb_wait                   BOOLEAN;
        ln_batch_cnt              NUMBER;
        ln_valid_rec_cnt          NUMBER;

        TYPE hdr_batch_id_t IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        ln_hdr_batch_id           hdr_batch_id_t;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id                  request_table;
    BEGIN
        errbuf          := NULL;
        retcode         := 0;
        gc_debug_flag   := p_debug;
        print_msg_prc (p_debug     => gc_debug_flag,
                       p_message   => 'p_candidate_set => ' || p_Process);

        print_msg_prc (p_debug     => gc_debug_flag,
                       p_message   => 'p_debug => ' || p_debug);

        print_msg_prc (p_debug     => gc_debug_flag,
                       p_message   => 'p_batch_size => ' || p_batch_size);

        IF p_process = gc_extract_only
        THEN
            extract_cat_to_stg (x_errbuf       => errbuf,
                                x_retcode      => retcode,
                                p_inv_org_id   => p_inv_org);
        ELSIF p_process = gc_validate_only
        THEN
            SELECT COUNT (*)
              INTO ln_valid_rec_cnt
              FROM XXD_INV_PROD_LINE_CAT_STG_T
             WHERE batch_number IS NULL AND RECORD_STATUS = gc_new_status;

            FOR i IN 1 .. p_batch_size
            LOOP
                BEGIN
                    SELECT XXTOP_ITEM_CATEGORIES_BATCH_S.NEXTVAL
                      INTO ln_hdr_batch_id (i)
                      FROM DUAL;

                    print_msg_prc (
                        gc_debug_flag,
                        'ln_hdr_batch_id(i) := ' || ln_hdr_batch_id (i));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_hdr_batch_id (i + 1)   := ln_hdr_batch_id (i) + 1;
                END;

                print_msg_prc (gc_debug_flag,
                               ' ln_valid_rec_cnt := ' || ln_valid_rec_cnt);
                print_msg_prc (
                    gc_debug_flag,
                       'ceil( ln_valid_rec_cnt/p_batch_size) := '
                    || CEIL (ln_valid_rec_cnt / p_batch_size));

                UPDATE XXD_INV_PROD_LINE_CAT_STG_T
                   SET batch_number = ln_hdr_batch_id (i), conc_request_id = ln_parent_request_id
                 WHERE     batch_number IS NULL
                       AND ROWNUM <= CEIL (ln_valid_rec_cnt / p_batch_size)
                       AND RECORD_STATUS = gc_new_status;
            END LOOP;

            COMMIT;

            FOR l IN 1 .. ln_hdr_batch_id.COUNT
            LOOP
                SELECT COUNT (*)
                  INTO ln_cntr
                  FROM XXD_INV_PROD_LINE_CAT_STG_T
                 WHERE     record_status = gc_new_status
                       AND batch_number = ln_hdr_batch_id (l);

                IF ln_cntr > 0
                THEN
                    BEGIN
                        ln_request_id   :=
                            apps.fnd_request.submit_request (
                                'XXDCONV',
                                'XXD_PROD_LINE_CAT_COV_CHILD_CP',
                                '',
                                '',
                                FALSE,
                                gc_debug_flag,
                                p_process,
                                ln_hdr_batch_id (l),
                                ln_parent_request_id);
                        print_msg_prc (gc_debug_flag,
                                       'v_request_id := ' || ln_request_id);

                        IF ln_request_id > 0
                        THEN
                            l_req_id (l)   := ln_request_id;
                            COMMIT;
                        ELSE
                            ROLLBACK;
                        END IF;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            retcode   := 2;
                            ERRBUF    := ERRBUF || SQLERRM;
                            print_msg_prc (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXD_PROD_LINE_CAT_COV_CHILD_CP error'
                                || SQLERRM);
                        WHEN OTHERS
                        THEN
                            retcode   := 2;
                            ERRBUF    := ERRBUF || SQLERRM;
                            print_msg_prc (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXD_PROD_LINE_CAT_COV_CHILD_CP error'
                                || SQLERRM);
                    END;
                END IF;
            END LOOP;
        ELSIF p_process = gc_load_only
        THEN
            ln_cntr   := 0;
            print_msg_prc (
                gc_debug_flag,
                'Fetching batch id from XXD_INV_PROD_LINE_CAT_STG_T stage to call worker process');

            FOR I
                IN (  SELECT DISTINCT batch_number
                        FROM XXD_INV_PROD_LINE_CAT_STG_T
                       WHERE     batch_number IS NOT NULL
                             AND RECORD_STATUS = gc_validate_status
                    ORDER BY batch_number)
            LOOP
                ln_cntr                     := ln_cntr + 1;
                ln_hdr_batch_id (ln_cntr)   := i.batch_number;
            END LOOP;

            print_msg_prc (
                gc_debug_flag,
                'completed updating Batch id in  XXD_INV_PROD_LINE_CAT_STG_T');

            COMMIT;

            IF ln_hdr_batch_id.COUNT > 0
            THEN
                print_msg_prc (
                    gc_debug_flag,
                       'Calling XXD_PROD_LINE_CAT_COV_CHILD_CP in batch '
                    || ln_hdr_batch_id.COUNT);

                FOR i IN ln_hdr_batch_id.FIRST .. ln_hdr_batch_id.LAST
                LOOP
                    SELECT COUNT (*)
                      INTO ln_cntr
                      FROM XXD_INV_PROD_LINE_CAT_STG_T
                     WHERE batch_number = ln_hdr_batch_id (i);


                    IF ln_cntr > 0
                    THEN
                        BEGIN
                            ln_request_id   :=
                                apps.fnd_request.submit_request (
                                    'XXDCONV',
                                    'XXD_PROD_LINE_CAT_COV_CHILD_CP',
                                    '',
                                    '',
                                    FALSE,
                                    gc_debug_flag,
                                    p_process,
                                    ln_hdr_batch_id (i),
                                    ln_parent_request_id);
                            print_msg_prc (
                                gc_debug_flag,
                                'v_request_id := ' || ln_request_id);

                            IF ln_request_id > 0
                            THEN
                                l_req_id (i)   := ln_request_id;
                                COMMIT;
                            ELSE
                                ROLLBACK;
                            END IF;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                retcode   := 2;
                                ERRBUF    := ERRBUF || SQLERRM;
                                print_msg_prc (
                                    gc_debug_flag,
                                       'Calling WAIT FOR REQUEST XXD_PROD_LINE_CAT_COV_CHILD_CP error'
                                    || SQLERRM);
                            WHEN OTHERS
                            THEN
                                retcode   := 2;
                                ERRBUF    := ERRBUF || SQLERRM;
                                print_msg_prc (
                                    gc_debug_flag,
                                       'Calling WAIT FOR REQUEST XXD_PROD_LINE_CAT_COV_CHILD_CP error'
                                    || SQLERRM);
                        END;
                    END IF;
                END LOOP;
            END IF;
        END IF;

        print_msg_prc (
            gc_debug_flag,
            'Calling XXD_PROD_LINE_CAT_COV_CHILD_CP in batch ' || l_req_id.COUNT);
        print_msg_prc (
            gc_debug_flag,
            'Calling WAIT FOR REQUEST XXD_PROD_LINE_CAT_COV_CHILD_CP to complete');

        IF l_req_id.COUNT > 0
        THEN
            FOR rec IN l_req_id.FIRST .. l_req_id.LAST
            LOOP
                IF l_req_id (rec) > 0
                THEN
                    LOOP
                        lc_dev_phase    := NULL;
                        lc_dev_status   := NULL;
                        lb_wait         :=
                            fnd_concurrent.wait_for_request (
                                request_id   => l_req_id (rec) --ln_concurrent_request_id
                                                              ,
                                interval     => 1,
                                max_wait     => 1,
                                phase        => lc_phase,
                                status       => lc_status,
                                dev_phase    => lc_dev_phase,
                                dev_status   => lc_dev_status,
                                MESSAGE      => lc_message);

                        IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                        THEN
                            EXIT;
                        END IF;
                    END LOOP;
                END IF;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SUBSTR (SQLERRM, 1, 250);
            retcode   := 2;
            print_msg_prc (p_debug     => gc_debug_flag,
                           p_message   => 'errbuf => ' || errbuf);
    END inv_category_main;
END XXD_PROD_LINE_CAT_CNV_PKG;
/
