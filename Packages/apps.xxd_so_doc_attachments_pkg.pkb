--
-- XXD_SO_DOC_ATTACHMENTS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:10 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_SO_DOC_ATTACHMENTS_PKG"
AS
    -- +==============================================================================+
    -- +                        Deckers BT Oracle 12i                                 +
    -- +==============================================================================+
    -- |                                                                              |
    -- |CVS ID:   1.1                                                                 |
    -- |Name:                                                                         |
    -- |Creation Date: 27-AUG-2015                                                    |
    -- |Application Name: Deckers Conversion Application                              |
    -- |Source File Name: XXD_SO_DOC_ATTACHMENTS_PKG.sql                         |
    -- |                                                                              |
    -- |Object Name :   XXD_SO_DOC_ATTACHMENTS_PKG                               |
    -- |Description   : The package  is defined to convert the                        |
    -- |                Deckers SO Document Attachments                                             |
    -- |                Conversion to R12                                             |
    -- |                                                                              |
    -- |Usage:                                                                        |
    -- |                                                                              |
    -- |Parameters   :                                                                |
    -- |                p_debug          -- Debug Flag                                  |
    -- |                                                                              |
    -- |                                                                              |
    -- |                                                                              |
    -- |Change Record:                                                                |
    -- |===============                                                               |
    -- |Version   Date             Author             Remarks                              |
    -- |=======   ==========  ===================   ============================      |
    -- |DRAFT 1A  27-AUG-2015                        Initial draft version            |
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

    PROCEDURE get_category_id (P_CATEGORY_DESCRIPTION IN VARCHAR2, P_DATATYPE_NAME IN VARCHAR2, P_TITLE IN VARCHAR2
                               , p_text IN XXD_SO_DOCUMENT_ATTACHMENTS_T.Text%TYPE, x_category_id OUT NUMBER, x_document_id OUT NUMBER)
    AS
        ln_media_id        NUMBER;
        ln_cnt_id          NUMBER;
        lc_DATATYPE_NAME   VARCHAR2 (250);
        lc_Long_Text       fnd_documents_long_text.Long_Text%TYPE;
    BEGIN
        print_msg_prc (p_debug     => gc_debug_flag,
                       p_message   => 'get_category_id p_text' || p_text);

        IF P_DATATYPE_NAME = 'Long Text'
        THEN
            print_msg_prc (p_debug     => gc_debug_flag,
                           p_message   => 'get_category_id p_text' || p_text);

            x_category_id   := 0;
            x_document_id   := 0;

            FOR I
                IN (SELECT category_id, document_id, MEDIA_ID,
                           DATATYPE_NAME
                      --            INTO x_category_id,x_document_id,ln_media_id,lc_DATATYPE_NAME
                      FROM FND_DOCUMENTS_VL x
                     WHERE     CATEGORY_DESCRIPTION = P_CATEGORY_DESCRIPTION
                           AND DATATYPE_NAME = P_DATATYPE_NAME
                           AND TITLE = P_TITLE)
            LOOP
                SELECT Long_Text
                  INTO lc_Long_Text
                  FROM fnd_documents_long_text a
                 WHERE a.MEDIA_ID = i.media_id;


                IF TO_CHAR (SUBSTR (lc_Long_Text, 1, 4000)) = p_text
                THEN
                    print_msg_prc (
                        p_debug     => gc_debug_flag,
                        p_message   => 'get_category_id lc_Long_Text TRUE');
                    x_category_id   := i.category_id;
                    x_document_id   := i.document_id;

                    RETURN;
                ELSE
                    x_category_id   := 0;
                    x_document_id   := 0;
                END IF;
            END LOOP;


            --

            print_msg_prc (
                p_debug     => gc_debug_flag,
                p_message   => 'get_category_id ln_media_id' || ln_media_id);

            --                SELECT Long_Text
            --                  INTO lc_Long_Text
            --                  FROM fnd_documents_long_text a
            --                 WHERE     a.MEDIA_ID = ln_media_id;
            --
            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'get_category_id lc_Long_Text'
                    || TO_CHAR (SUBSTR (lc_Long_Text, 1, 4000)));
        ELSIF P_DATATYPE_NAME = 'Short Text'
        THEN
            FOR I
                IN (SELECT category_id, document_id, MEDIA_ID,
                           DATATYPE_NAME
                      --            INTO x_category_id,x_document_id,ln_media_id,lc_DATATYPE_NAME
                      FROM FND_DOCUMENTS_VL x
                     WHERE     CATEGORY_DESCRIPTION = P_CATEGORY_DESCRIPTION
                           AND DATATYPE_NAME = P_DATATYPE_NAME
                           AND TITLE = P_TITLE)
            LOOP
                x_category_id   := i.category_id;
                x_document_id   := i.document_id;

                RETURN;
            END LOOP;


            --

            print_msg_prc (
                p_debug     => gc_debug_flag,
                p_message   => 'get_category_id ln_media_id' || ln_media_id);
        END IF;
    --             RETURN ln_category_id ;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_category_id   := 0;
            x_document_id   := 0;
        WHEN OTHERS
        THEN
            x_category_id   := NULL;
            x_document_id   := NULL;
            print_msg_prc (p_debug     => gc_debug_flag,
                           p_message   => 'get_category_id' || SQLERRM);
    END get_category_id;

    /*
  PROCEDURE get_category_id (P_CATEGORY_DESCRIPTION   IN VARCHAR2
                           , P_DATATYPE_NAME          IN VARCHAR2
                           , P_TITLE                  IN VARCHAR2
                           , x_category_id            OUT NUMBER
                           , x_document_id            OUT NUMBER)  AS
  ln_media_id   NUMBER;
  ln_cnt_id   NUMBER;
  lc_DATATYPE_NAME  VARCHAR2(250);
  BEGIN

        SELECT category_id,document_id--,MEDIA_ID,DATATYPE_NAME
          INTO x_category_id,x_document_id--,ln_media_id,lc_DATATYPE_NAME
          FROM FND_DOCUMENTS_VL x
         WHERE     CATEGORY_DESCRIPTION = P_CATEGORY_DESCRIPTION
               AND DATATYPE_NAME = P_DATATYPE_NAME
               AND TITLE = P_TITLE ;

  --             RETURN ln_category_id ;
     EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
           x_category_id := 0 ;
           x_document_id := 0 ;
        WHEN OTHERS
        THEN
           x_category_id := NULL ;
           x_document_id := NULL ;
            print_msg_prc( p_debug   => gc_debug_flag
                      ,p_message =>  'get_category_id'|| SQLERRM);

     END get_category_id;

  */
    FUNCTION get_category_id (P_CATEGORY_DESCRIPTION IN VARCHAR2)
        RETURN NUMBER
    AS
        ln_category_id   NUMBER;
    BEGIN
        SELECT category_id
          INTO ln_category_id
          FROM fnd_document_categories_vl
         WHERE user_name = P_CATEGORY_DESCRIPTION;

        RETURN ln_category_id;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            ln_category_id   := 0;
            RETURN ln_category_id;
        WHEN OTHERS
        THEN
            ln_category_id   := NULL;
            RETURN ln_category_id;
    END get_category_id;


    FUNCTION get_cust_account_id (P_ACCOUNT_NUMBER IN VARCHAR2)
        RETURN NUMBER
    AS
        ln_cust_account_id   NUMBER;
    BEGIN
        SELECT CUST_ACCOUNT_ID
          INTO ln_cust_account_id
          FROM hz_cust_accounts_all
         WHERE account_number = P_ACCOUNT_NUMBER;

        RETURN ln_cust_account_id;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            ln_cust_account_id   := 0;
            RETURN ln_cust_account_id;
        WHEN OTHERS
        THEN
            ln_cust_account_id   := NULL;
            RETURN ln_cust_account_id;
    END get_cust_account_id;

    PROCEDURE extract_1206_so_attach_data (x_errbuf    OUT VARCHAR2,
                                           x_retcode   OUT NUMBER)
    AS
        lv_error_stage        VARCHAR2 (50) := NULL;
        ln_record_count       NUMBER := 0;
        lv_string             LONG;
        v_order_source        VARCHAR2 (50) := NULL;
        v_conversion          VARCHAR2 (1) := NULL;
        v_item_level          VARCHAR2 (50) := NULL;
        gc_new_status         VARCHAR2 (10) := 'NEW';

        CURSOR cu_extract_count IS
            SELECT COUNT (*)
              FROM XXD_SO_DOCUMENT_ATTACHMENTS_T
             WHERE record_status = gc_new_status;

        --AND    source_org    = p_source_org_id;


        CURSOR lcu_ship_attach_data IS
            SELECT NULL RECORD_ID, 'NEW' RECORD_STATUS, gn_request_id REQUEST_ID,
                   'Shipping Instructions' Category, hp.party_name Title, hp.party_name Description,
                   'Long Text' Data_Type, 'None' Security, dcl.attribute_large Text,
                   'Order Header' Entity, RANK () OVER (PARTITION BY hp.party_name, dcl.attribute_large ORDER BY hca.attribute1) * 10 Group_Number, 'Customer' Attribute,
                   hca.account_number Attribute_Value, SYSDATE CREATION_DATE, gn_user_id CREATED_BY,
                   gn_user_id LAST_UPDATED_BY, gn_login_id LAST_UPDATE_LOGIN, SYSDATE LAST_UPDATE_DATE
              FROM do_custom.do_customer_lookups@BT_READ_1206 dcl, apps.hz_cust_accounts hca, apps.hz_parties hp
             WHERE     dcl.customer_id = REGEXP_SUBSTR (hca.orig_system_reference, '[^-]+', 1
                                                        , 1)
                   AND hca.attribute1 <> 'ALL BRAND'
                   AND hca.party_id = hp.party_id
                   AND dcl.lookup_type = 'DO_DEF_SHIPPING_INSTRUCTS'
                   AND dcl.enabled_flag = 'Y'
                   AND dcl.lookup_value = 'Y'
                   AND dcl.brand = 'ALL'
                   --and dcl.customer_id=1753
                   AND (hca.account_number, hca.attribute1) NOT IN
                           (SELECT hca1.account_number, hca1.attribute1
                              FROM do_custom.do_customer_lookups@BT_READ_1206 dcl1, apps.hz_cust_accounts hca1, apps.hz_parties hp1
                             WHERE     dcl1.customer_id = REGEXP_SUBSTR (hca1.orig_system_reference, '[^-]+', 1
                                                                         , 1)
                                   AND hca1.attribute1 <> 'ALL BRAND'
                                   AND hca1.party_id = hp1.party_id
                                   AND dcl1.lookup_type =
                                       'DO_DEF_SHIPPING_INSTRUCTS'
                                   AND dcl1.enabled_flag = 'Y'
                                   AND dcl1.lookup_value = 'Y'
                                   AND dcl1.brand = hca1.attribute1 --and dcl1.customer_id=1753
                                                                   )
            UNION
            SELECT NULL RECORD_ID, 'NEW' RECORD_STATUS, gn_request_id REQUEST_ID,
                   'Shipping Instructions' Category, hp.party_name Title, hp.party_name Description,
                   'Long Text' Data_Type, 'None' Security, dcl.attribute_large Text,
                   'Order Header' Entity, RANK () OVER (PARTITION BY hp.party_name, dcl.attribute_large ORDER BY hca.attribute1) * 10 Group_Number, 'Customer' Attribute,
                   hca.account_number Attribute_Value, SYSDATE CREATION_DATE, gn_user_id CREATED_BY,
                   gn_user_id LAST_UPDATED_BY, gn_login_id LAST_UPDATE_LOGIN, SYSDATE LAST_UPDATE_DATE
              FROM do_custom.do_customer_lookups@BT_READ_1206 dcl, apps.hz_cust_accounts hca, apps.hz_parties hp
             WHERE     dcl.customer_id = REGEXP_SUBSTR (hca.orig_system_reference, '[^-]+', 1
                                                        , 1)
                   AND hca.attribute1 <> 'ALL BRAND'
                   AND hca.party_id = hp.party_id
                   AND dcl.lookup_type = 'DO_DEF_SHIPPING_INSTRUCTS'
                   AND dcl.enabled_flag = 'Y'
                   AND dcl.lookup_value = 'Y'
                   AND dcl.brand = hca.attribute1;

        --and customer_id=1753;
        CURSOR lcu_pack_attach_data IS
            SELECT NULL RECORD_ID, 'NEW' RECORD_STATUS, gn_request_id REQUEST_ID,
                   'Packing Instructions' Category, hp.party_name Title, hp.party_name Description,
                   'Long Text' Data_Type, 'None' Security, dcl.attribute_large Text,
                   'Order Header' Entity, RANK () OVER (PARTITION BY hp.party_name, dcl.attribute_large ORDER BY hca.attribute1) * 10 Group_Number, 'Customer' Attribute,
                   hca.account_number Attribute_Value, SYSDATE CREATION_DATE, gn_user_id CREATED_BY,
                   gn_user_id LAST_UPDATED_BY, gn_login_id LAST_UPDATE_LOGIN, SYSDATE LAST_UPDATE_DATE
              FROM do_custom.do_customer_lookups@BT_READ_1206 dcl, apps.hz_cust_accounts hca, apps.hz_parties hp
             WHERE     dcl.customer_id = REGEXP_SUBSTR (hca.orig_system_reference, '[^-]+', 1
                                                        , 1)
                   AND hca.attribute1 <> 'ALL BRAND'
                   AND hca.party_id = hp.party_id
                   AND dcl.lookup_type = 'DO_DEF_PACKING_INSTRUCTS'
                   AND dcl.enabled_flag = 'Y'
                   AND dcl.lookup_value = 'Y'
                   AND dcl.brand = 'ALL'
                   --and dcl.customer_id=1753
                   AND (hca.account_number, hca.attribute1) NOT IN
                           (SELECT hca1.account_number, hca1.attribute1
                              FROM do_custom.do_customer_lookups@BT_READ_1206 dcl1, apps.hz_cust_accounts hca1, apps.hz_parties hp1
                             WHERE     dcl1.customer_id = REGEXP_SUBSTR (hca1.orig_system_reference, '[^-]+', 1
                                                                         , 1)
                                   AND hca1.attribute1 <> 'ALL BRAND'
                                   AND hca1.party_id = hp1.party_id
                                   AND dcl1.lookup_type =
                                       'DO_DEF_PACKING_INSTRUCTS'
                                   AND dcl1.enabled_flag = 'Y'
                                   AND dcl1.lookup_value = 'Y'
                                   AND dcl1.brand = hca1.attribute1 --and dcl1.customer_id=1753
                                                                   )
            UNION
            SELECT NULL RECORD_ID, 'NEW' RECORD_STATUS, gn_request_id REQUEST_ID,
                   'Packing Instructions' Category, hp.party_name Title, hp.party_name Description,
                   'Long Text' Data_Type, 'None' Security, dcl.attribute_large Text,
                   'Order Header' Entity, RANK () OVER (PARTITION BY hp.party_name, dcl.attribute_large ORDER BY hca.attribute1) * 10 Group_Number, 'Customer' Attribute,
                   hca.account_number Attribute_Value, SYSDATE CREATION_DATE, gn_user_id CREATED_BY,
                   gn_user_id LAST_UPDATED_BY, gn_login_id LAST_UPDATE_LOGIN, SYSDATE LAST_UPDATE_DATE
              FROM do_custom.do_customer_lookups@BT_READ_1206 dcl, apps.hz_cust_accounts hca, apps.hz_parties hp
             WHERE     dcl.customer_id = REGEXP_SUBSTR (hca.orig_system_reference, '[^-]+', 1
                                                        , 1)
                   AND hca.attribute1 <> 'ALL BRAND'
                   AND hca.party_id = hp.party_id
                   AND dcl.lookup_type = 'DO_DEF_PACKING_INSTRUCTS'
                   AND dcl.enabled_flag = 'Y'
                   AND dcl.lookup_value = 'Y'
                   AND dcl.brand = hca.attribute1;

        TYPE XXD_SO_ATT_TAB IS TABLE OF lcu_ship_attach_data%ROWTYPE
            INDEX BY BINARY_INTEGER;

        gtt_1206_so_doc_tab   XXD_SO_ATT_TAB;
    BEGIN
        gtt_1206_so_doc_tab.delete;

        EXECUTE IMMEDIATE 'TRUNCATE TABLE XXD_CONV.XXD_SO_DOCUMENT_ATTACHMENTS_T';

        OPEN lcu_ship_attach_data;

        LOOP
            lv_error_stage   := 'Inserting Shipping  Data';
            print_msg_prc (p_debug     => gc_debug_flag,
                           p_message   => lv_error_stage);

            --gtt_1206_price_list_tab.delete;

            FETCH lcu_ship_attach_data
                BULK COLLECT INTO gtt_1206_so_doc_tab
                LIMIT 500;

            FOR i IN 1 .. gtt_1206_so_doc_tab.COUNT
            LOOP
                --            print_msg_prc( p_debug   => gc_debug_flag
                --                    ,p_message =>
                --                               'COUNT :' || gtt_1206_so_doc_tab.COUNT);

                gtt_1206_so_doc_tab (i).record_id   :=
                    XXD_SO_DOCUMENT_ATTACHMENTS_S.NEXTVAL;

                --             gtt_1206_so_doc_tab (i).request_id := gn_request_id ;
                --              gtt_1206_so_doc_tab (i).Category  := trunc( gtt_1206_so_doc_tab (i).Category)  ;

                INSERT INTO XXD_SO_DOCUMENT_ATTACHMENTS_T
                     VALUES gtt_1206_so_doc_tab (i);

                gtt_1206_so_doc_tab.delete;
            END LOOP;

            COMMIT;
            EXIT WHEN lcu_ship_attach_data%NOTFOUND;
        END LOOP;

        COMMIT;

        CLOSE lcu_ship_attach_data;

        gtt_1206_so_doc_tab.delete;


        OPEN lcu_pack_attach_data;

        LOOP
            lv_error_stage   := 'Inserting Packing Instructions list Data';
            print_msg_prc (p_debug     => gc_debug_flag,
                           p_message   => lv_error_stage);

            --gtt_1206_price_list_tab.delete;

            FETCH lcu_pack_attach_data
                BULK COLLECT INTO gtt_1206_so_doc_tab
                LIMIT 500;

            FOR i IN 1 .. gtt_1206_so_doc_tab.COUNT
            LOOP
                --            print_msg_prc( p_debug   => gc_debug_flag
                --                    ,p_message =>
                --                               'COUNT :' || gtt_1206_so_doc_tab.COUNT);

                gtt_1206_so_doc_tab (i).record_id   :=
                    XXD_SO_DOCUMENT_ATTACHMENTS_S.NEXTVAL;

                --             gtt_1206_so_doc_tab (i).request_id := gn_request_id ;

                INSERT INTO XXD_SO_DOCUMENT_ATTACHMENTS_T
                     VALUES gtt_1206_so_doc_tab (i);

                gtt_1206_so_doc_tab.delete;
            END LOOP;

            COMMIT;
            EXIT WHEN lcu_pack_attach_data%NOTFOUND;
        END LOOP;

        COMMIT;

        CLOSE lcu_pack_attach_data;

        UPDATE XXD_SO_DOCUMENT_ATTACHMENTS_T x
           SET category   = 'Packing Instructions'
         WHERE category LIKE 'Packing%';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuf    := SQLERRM;
            x_retcode   := 1;
            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'Error Inserting record In '
                    || lv_error_stage
                    || ' : '
                    || SQLERRM);
            print_msg_prc (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'Error Inserting record In '
                    || lv_error_stage
                    || ' : '
                    || SQLERRM);
            print_msg_prc (p_debug     => gc_debug_flag,
                           p_message   => 'Exception ' || SQLERRM);
    END extract_1206_so_attach_data;

    ------End of adding the Extract Procedure on 21-Apr-2015

    PROCEDURE so_doc_attachment_main (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY NUMBER, p_debug IN VARCHAR2)
    IS
        ln_category_id           NUMBER := 0;
        ln_document_id           NUMBER := 0;
        ln_datatype_id           NUMBER := 0;
        ln_media_id              NUMBER := 0;
        ln_rowid                 ROWID;
        l_database_object_name   VARCHAR2 (500);
        ln_rule_id               NUMBER := 0;
        l_rule_element_id        NUMBER := 0;
        ln_attribute_value       NUMBER := 0;

        CURSOR C IS
            SELECT ROWID
              FROM oe_attachment_rule_elements
             WHERE rule_element_id = l_rule_element_id;
    BEGIN
        errbuf           := NULL;
        retcode          := 0;
        ln_category_id   := 0;
        gc_debug_flag    := p_debug;

        print_msg_prc (p_debug     => gc_debug_flag,
                       p_message   => 'p_debug => ' || p_debug);

        --    extract_1206_so_attach_data (x_errbuf    => errbuf,
        --                                 x_retcode   => retcode) ;

        FOR so_doc_rec IN (SELECT *
                             FROM XXD_SO_DOCUMENT_ATTACHMENTS_T
                            WHERE RECORD_STATUS = gc_new_status)
        LOOP
            BEGIN
                print_msg_prc (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'get_category_id so_doc_rec.CATEGORY => '
                        || so_doc_rec.CATEGORY);
                print_msg_prc (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'get_category_id so_doc_rec.DATA_TYPE => '
                        || so_doc_rec.DATA_TYPE);
                print_msg_prc (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                        'get_category_id so_doc_rec.TITLE => ' || so_doc_rec.TITLE);
                print_msg_prc (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                        'get_category_id so_doc_rec.TEXT => ' || so_doc_rec.TEXT);
                ln_attribute_value   :=
                    get_cust_account_id (
                        P_ACCOUNT_NUMBER => so_doc_rec.ATTRIBUTE_VALUE);
                print_msg_prc (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'get_category_id ln_attribute_value => '
                        || so_doc_rec.ATTRIBUTE_VALUE);

                IF ln_attribute_value IS NOT NULL
                THEN
                    get_category_id (
                        P_CATEGORY_DESCRIPTION   => so_doc_rec.CATEGORY,
                        P_DATATYPE_NAME          => so_doc_rec.DATA_TYPE,
                        P_TITLE                  => so_doc_rec.TITLE,
                        P_TEXT                   => so_doc_rec.TEXT,
                        x_category_id            => ln_category_id,
                        x_document_id            => ln_document_id);
                    print_msg_prc (
                        p_debug     => gc_debug_flag,
                        p_message   => 'get_category_id => ' || ln_category_id);
                    print_msg_prc (
                        p_debug     => gc_debug_flag,
                        p_message   => 'ln_document_id => ' || ln_document_id);

                    IF     NVL (ln_category_id, 0) = 0
                       AND NVL (ln_document_id, 0) = 0
                    THEN
                        print_msg_prc (
                            p_debug   => gc_debug_flag,
                            p_message   =>
                                   'get_category_id so_doc_rec.CATEGORY => '
                                || so_doc_rec.CATEGORY);

                        ln_category_id   :=
                            get_category_id (
                                P_CATEGORY_DESCRIPTION => so_doc_rec.CATEGORY);
                        print_msg_prc (
                            p_debug   => gc_debug_flag,
                            p_message   =>
                                   'get_category_id so_doc_rec.ln_category_id => '
                                || ln_category_id);

                        IF NVL (ln_category_id, 0) <> 0
                        THEN
                            print_msg_prc (
                                p_debug   => gc_debug_flag,
                                p_message   =>
                                       'create document for title => '
                                    || so_doc_rec.TITLE);

                            BEGIN
                                ln_document_id   := 0;
                                ln_media_id      := 0;
                                ln_rowid         := NULL;

                                --                 ln_datatype_id ('Long Text' ,2,'Short Text' ,1)


                                BEGIN
                                    SELECT DECODE (so_doc_rec.DATA_TYPE,  'Long Text', 2,  'Short Text', 1,  6)
                                      INTO ln_datatype_id
                                      FROM DUAL;
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        ln_datatype_id   := 2;
                                    WHEN OTHERS
                                    THEN
                                        ln_datatype_id   := 2;
                                END;

                                SELECT fnd_documents_s.NEXTVAL
                                  INTO ln_document_id
                                  FROM DUAL;

                                print_msg_prc (
                                    p_debug   => gc_debug_flag,
                                    p_message   =>
                                           'create document for DATA_TYPE => '
                                        || so_doc_rec.DATA_TYPE);
                                print_msg_prc (
                                    p_debug   => gc_debug_flag,
                                    p_message   =>
                                           'create document for ln_document_id => '
                                        || ln_document_id);
                                print_msg_prc (
                                    p_debug   => gc_debug_flag,
                                    p_message   =>
                                           'create document for ln_datatype_id => '
                                        || ln_datatype_id);
                                print_msg_prc (
                                    p_debug   => gc_debug_flag,
                                    p_message   =>
                                           'create document for ln_category_id => '
                                        || ln_category_id);
                                print_msg_prc (
                                    p_debug   => gc_debug_flag,
                                    p_message   =>
                                           'create document for so_doc_rec.DESCRIPTION => '
                                        || so_doc_rec.DESCRIPTION);
                                FND_DOCUMENTS_PKG.INSERT_ROW (
                                    x_rowid               => ln_rowid,
                                    x_document_id         => ln_document_id,
                                    x_creation_date       => SYSDATE,
                                    x_created_by          => gn_user_id,
                                    x_last_update_date    => SYSDATE,
                                    x_last_updated_by     => gn_user_id,
                                    x_last_update_login   => gn_login_id,
                                    x_datatype_id         => ln_datatype_id,
                                    x_category_id         => ln_category_id,
                                    x_security_type       => 4,
                                    x_publish_flag        => 'N',
                                    x_usage_type          => 'S',
                                    x_language            => 'US',
                                    x_description         =>
                                        so_doc_rec.DESCRIPTION,
                                    x_file_name           => NULL,
                                    x_media_id            => ln_media_id,
                                    x_title               => so_doc_rec.TITLE);
                            END;


                            print_msg_prc (
                                p_debug   => gc_debug_flag,
                                p_message   =>
                                       'create document for ln_media_id => '
                                    || ln_media_id);

                            IF ln_datatype_id = 6 AND ln_media_id > 0
                            THEN     --                              File Type
                                BEGIN
                                    /*   INSERT INTO FND_LOBS
                                                   (file_id
                                                   ,file_name
                                                   ,file_content_type
                                                   ,upload_date
                                                   ,expiration_date
                                                   ,program_name
                                                   ,program_tag
                                                   ,file_data
                                                   ,language
                                                   ,oracle_charset
                                                   ,file_format
                                                   )
                                                   VALUES
                                                   (
                                                   ln_media_id,
                                                   'file_name',
                                                   indx_stand_doc_det_ds_rec.file_content_type,
                                                   sysdate,
                                                   null,
                                                   indx_stand_doc_det_ds_rec.program_name,
                                                   null,
                                                   ln_blob,
                                                   'US',
                                                   indx_stand_doc_det_ds_rec.oracle_charset,
                                                   indx_stand_doc_det_ds_rec.file_format
                                                   )
                                                   returning file_data
                                                   INTO ln_blob;
                                                   */
                                    NULL;
                                END;
                            ELSIF ln_datatype_id = 2 AND ln_media_id > 0
                            THEN                   --                Long Text
                                BEGIN
                                    --                                    SELECT fdl.long_text
                                    --                                      INTO ln_long
                                    --                                      FROM fnd_documents_long_text fdl
                                    --                                     WHERE fdl.media_id = ln_media_id;

                                    INSERT INTO fnd_documents_long_text (
                                                    media_id,
                                                    long_text)
                                             VALUES (ln_media_id,
                                                     so_doc_rec.text);
                                END;
                            ELSIF ln_datatype_id = 1 AND ln_media_id > 0
                            THEN                    --              Short Text
                                BEGIN
                                    --                                    BEGIN
                                    ----                                        SELECT fds.short_text
                                    ----                                                  INTO ln_short
                                    ----                                                  FROM fnd_documents_short_text fds
                                    ----                                                 WHERE fds.media_id = ln_media_id;
                                    --                                    EXCEPTION
                                    --                                       WHEN NO_DATA_FOUND THEN
                                    --                                          NULL;
                                    --                                       WHEN OTHERS THEN
                                    --                                          NULL;
                                    --                                    END;
                                    INSERT INTO apps.fnd_documents_short_text (
                                                    media_id,
                                                    short_text)
                                             VALUES (ln_media_id,
                                                     so_doc_rec.text);
                                END;
                            END IF;      --ln_datatype_id long or shor or file


                            --                                 print_msg_prc(p_debug => gc_debug_flag ,p_message => 'create document for INSERT_TL_ROW => '||ln_document_id) ;
                            /*  BEGIN
                                 FND_DOCUMENTS_PKG.INSERT_TL_ROW (x_document_id => ln_document_id,
                                                                  x_creation_date => SYSDATE,
                                                                  x_created_by => gn_user_id,
                                                                  x_last_update_date => SYSDATE,
                                                                  x_last_updated_by => gn_user_id,
                                                                  x_last_update_login => gn_login_id,
                                                                  x_language  => 'US',
                                                                  x_description => so_doc_rec.DESCRIPTION,
                                                                  x_title     => so_doc_rec.TITLE);
                              END;*/

                            print_msg_prc (
                                p_debug   => gc_debug_flag,
                                p_message   =>
                                       'create document for oe_attachment_rules_s => '
                                    || ln_document_id);

                            SELECT oe_attachment_rules_s.NEXTVAL
                              INTO ln_rule_id
                              FROM DUAL;

                            ln_rowid   := NULL;
                            print_msg_prc (
                                p_debug   => gc_debug_flag,
                                p_message   =>
                                       'create document for ln_rule_id => '
                                    || ln_rule_id);

                            IF so_doc_rec.ENTITY = 'Order Header'
                            THEN
                                l_DATABASE_OBJECT_NAME   :=
                                    'OE_AK_ORDER_HEADERS_V';
                            ELSE
                                l_DATABASE_OBJECT_NAME   :=
                                    'OE_AK_ORDER_LINES_V';
                            END IF;

                            print_msg_prc (
                                p_debug   => gc_debug_flag,
                                p_message   =>
                                       'create document for l_DATABASE_OBJECT_NAME => '
                                    || l_DATABASE_OBJECT_NAME);
                            print_msg_prc (
                                p_debug   => gc_debug_flag,
                                p_message   =>
                                       'create document for ln_document_id => '
                                    || ln_document_id);
                            OE_ATTACHMENT_RULES_PKG.INSERT_ROW (
                                X_ROWID                  => ln_rowid,
                                X_RULE_ID                => ln_rule_id,
                                X_DATABASE_OBJECT_NAME   =>
                                    l_database_object_name,
                                X_DOCUMENT_ID            => ln_document_id,
                                X_CONTEXT                => NULL,
                                X_ATTRIBUTE1             => NULL,
                                X_ATTRIBUTE2             => NULL,
                                X_ATTRIBUTE3             => NULL,
                                X_ATTRIBUTE4             => NULL,
                                X_ATTRIBUTE5             => NULL,
                                X_ATTRIBUTE6             => NULL,
                                X_ATTRIBUTE7             => NULL,
                                X_ATTRIBUTE8             => NULL,
                                X_ATTRIBUTE9             => NULL,
                                X_ATTRIBUTE10            => NULL,
                                X_ATTRIBUTE11            => NULL,
                                X_ATTRIBUTE12            => NULL,
                                X_ATTRIBUTE13            => NULL,
                                X_ATTRIBUTE14            => NULL,
                                X_ATTRIBUTE15            => NULL,
                                X_CREATION_DATE          => SYSDATE,
                                X_CREATED_BY             => gn_user_id,
                                X_LAST_UPDATE_DATE       => SYSDATE,
                                X_LAST_UPDATED_BY        => gn_user_id,
                                X_LAST_UPDATE_LOGIN      => gn_login_id);



                            print_msg_prc (
                                p_debug   => gc_debug_flag,
                                p_message   =>
                                       'create document for ln_rule_id  last=> '
                                    || ln_rule_id);

                            SELECT oe_attachment_rule_elements_s.NEXTVAL
                              INTO l_rule_element_id
                              FROM DUAL;

                            OE_ATT_RULE_ELEMENTS_PKG.INSERT_ROW (
                                X_ROWID               => ln_rowid,
                                X_RULE_ELEMENT_ID     => l_rule_element_id,
                                X_RULE_ID             => ln_rule_id,
                                X_GROUP_NUMBER        => so_doc_rec.GROUP_NUMBER,
                                X_ATTRIBUTE_CODE      => 'SOLD_TO_ORG_ID',
                                X_ATTRIBUTE_VALUE     => ln_attribute_value,
                                X_CONTEXT             => NULL,
                                X_ATTRIBUTE1          => NULL,
                                X_ATTRIBUTE2          => NULL,
                                X_ATTRIBUTE3          => NULL,
                                X_ATTRIBUTE4          => NULL,
                                X_ATTRIBUTE5          => NULL,
                                X_ATTRIBUTE6          => NULL,
                                X_ATTRIBUTE7          => NULL,
                                X_ATTRIBUTE8          => NULL,
                                X_ATTRIBUTE9          => NULL,
                                X_ATTRIBUTE10         => NULL,
                                X_ATTRIBUTE11         => NULL,
                                X_ATTRIBUTE12         => NULL,
                                X_ATTRIBUTE13         => NULL,
                                X_ATTRIBUTE14         => NULL,
                                X_ATTRIBUTE15         => NULL,
                                X_CREATION_DATE       => SYSDATE,
                                X_CREATED_BY          => gn_user_id,
                                X_LAST_UPDATE_DATE    => SYSDATE,
                                X_LAST_UPDATED_BY     => gn_user_id,
                                X_LAST_UPDATE_LOGIN   => gn_login_id);
                        END IF;                  -- nvl(ln_category_id,0) <> 0
                    ELSE
                        print_msg_prc (
                            p_debug   => gc_debug_flag,
                            p_message   =>
                                'ELSE  ln_document_id > 0 and ln_category_id => 0');

                        BEGIN
                            ln_rowid   := NULL;
                            print_msg_prc (
                                p_debug   => gc_debug_flag,
                                p_message   =>
                                    'ln_document_id =>' || ln_document_id);
                            print_msg_prc (
                                p_debug   => gc_debug_flag,
                                p_message   =>
                                    'ln_category_id =>' || ln_category_id);
                            print_msg_prc (
                                p_debug     => gc_debug_flag,
                                p_message   => 'CATEGORY =>' || so_doc_rec.CATEGORY);
                            print_msg_prc (
                                p_debug     => gc_debug_flag,
                                p_message   => 'DATA_TYPE =>' || so_doc_rec.DATA_TYPE);
                            print_msg_prc (
                                p_debug     => gc_debug_flag,
                                p_message   => 'TITLE =>' || so_doc_rec.TITLE);
                            --                  print_msg_prc(p_debug => gc_debug_flag ,p_message =>'TEXT =>' ||so_doc_rec.TEXT);

                            print_msg_prc (
                                p_debug   => gc_debug_flag,
                                p_message   =>
                                       'create document for ln_document_id last=> '
                                    || ln_document_id);
                            print_msg_prc (
                                p_debug   => gc_debug_flag,
                                p_message   =>
                                       'create document for ln_category_id  last=> '
                                    || ln_category_id);

                            IF NVL (ln_document_id, 0) > 0
                            THEN
                                IF so_doc_rec.ENTITY = 'Order Header'
                                THEN
                                    l_DATABASE_OBJECT_NAME   :=
                                        'OE_AK_ORDER_HEADERS_V';
                                ELSE
                                    l_DATABASE_OBJECT_NAME   :=
                                        'OE_AK_ORDER_LINES_V';
                                END IF;

                                print_msg_prc (
                                    p_debug   => gc_debug_flag,
                                    p_message   =>
                                           'create document for SOLD_TO_ORG_ID  last=> '
                                        || ln_attribute_value);


                                BEGIN
                                    SELECT rule_id
                                      INTO ln_rule_id
                                      FROM oe_attachment_rules
                                     WHERE     DOCUMENT_ID = ln_document_id
                                           AND DATABASE_OBJECT_NAME =
                                               l_database_object_name;
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        ln_rule_id   := 0;
                                    WHEN OTHERS
                                    THEN
                                        ln_rule_id   := NULL;
                                END;

                                IF ln_rule_id = 0
                                THEN
                                    print_msg_prc (
                                        p_debug   => gc_debug_flag,
                                        p_message   =>
                                               'create document for oe_attachment_rules_s => '
                                            || ln_document_id);

                                    SELECT oe_attachment_rules_s.NEXTVAL
                                      INTO ln_rule_id
                                      FROM DUAL;

                                    ln_rowid   := NULL;
                                    print_msg_prc (
                                        p_debug   => gc_debug_flag,
                                        p_message   =>
                                               'create document for ln_rule_id => '
                                            || ln_rule_id);


                                    print_msg_prc (
                                        p_debug   => gc_debug_flag,
                                        p_message   =>
                                               'create document for l_DATABASE_OBJECT_NAME => '
                                            || l_DATABASE_OBJECT_NAME);
                                    print_msg_prc (
                                        p_debug   => gc_debug_flag,
                                        p_message   =>
                                               'create document for ln_document_id => '
                                            || ln_document_id);
                                    OE_ATTACHMENT_RULES_PKG.INSERT_ROW (
                                        X_ROWID               => ln_rowid,
                                        X_RULE_ID             => ln_rule_id,
                                        X_DATABASE_OBJECT_NAME   =>
                                            l_database_object_name,
                                        X_DOCUMENT_ID         => ln_document_id,
                                        X_CONTEXT             => NULL,
                                        X_ATTRIBUTE1          => NULL,
                                        X_ATTRIBUTE2          => NULL,
                                        X_ATTRIBUTE3          => NULL,
                                        X_ATTRIBUTE4          => NULL,
                                        X_ATTRIBUTE5          => NULL,
                                        X_ATTRIBUTE6          => NULL,
                                        X_ATTRIBUTE7          => NULL,
                                        X_ATTRIBUTE8          => NULL,
                                        X_ATTRIBUTE9          => NULL,
                                        X_ATTRIBUTE10         => NULL,
                                        X_ATTRIBUTE11         => NULL,
                                        X_ATTRIBUTE12         => NULL,
                                        X_ATTRIBUTE13         => NULL,
                                        X_ATTRIBUTE14         => NULL,
                                        X_ATTRIBUTE15         => NULL,
                                        X_CREATION_DATE       => SYSDATE,
                                        X_CREATED_BY          => gn_user_id,
                                        X_LAST_UPDATE_DATE    => SYSDATE,
                                        X_LAST_UPDATED_BY     => gn_user_id,
                                        X_LAST_UPDATE_LOGIN   => gn_login_id);
                                END IF;


                                print_msg_prc (
                                    p_debug   => gc_debug_flag,
                                    p_message   =>
                                           'create document for ln_rule_id  last=> '
                                        || ln_rule_id);


                                BEGIN
                                    SELECT rule_element_id
                                      INTO l_rule_element_id
                                      FROM oe_attachment_rule_elements
                                     WHERE     rule_id = ln_rule_id
                                           AND attribute_value =
                                               ln_attribute_value;
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        l_rule_element_id   := 0;
                                    WHEN OTHERS
                                    THEN
                                        l_rule_element_id   := NULL;
                                END;

                                print_msg_prc (
                                    p_debug   => gc_debug_flag,
                                    p_message   =>
                                           'create document for l_rule_element_id  last=> '
                                        || l_rule_element_id);

                                IF l_rule_element_id = 0
                                THEN
                                    SELECT oe_attachment_rule_elements_s.NEXTVAL
                                      INTO l_rule_element_id
                                      FROM DUAL;

                                    OE_ATT_RULE_ELEMENTS_PKG.INSERT_ROW (
                                        X_ROWID               => ln_rowid,
                                        X_RULE_ELEMENT_ID     =>
                                            l_rule_element_id,
                                        X_RULE_ID             => ln_rule_id,
                                        X_GROUP_NUMBER        =>
                                            so_doc_rec.GROUP_NUMBER,
                                        X_ATTRIBUTE_CODE      => 'SOLD_TO_ORG_ID',
                                        X_ATTRIBUTE_VALUE     =>
                                            ln_attribute_value,
                                        X_CONTEXT             => NULL,
                                        X_ATTRIBUTE1          => NULL,
                                        X_ATTRIBUTE2          => NULL,
                                        X_ATTRIBUTE3          => NULL,
                                        X_ATTRIBUTE4          => NULL,
                                        X_ATTRIBUTE5          => NULL,
                                        X_ATTRIBUTE6          => NULL,
                                        X_ATTRIBUTE7          => NULL,
                                        X_ATTRIBUTE8          => NULL,
                                        X_ATTRIBUTE9          => NULL,
                                        X_ATTRIBUTE10         => NULL,
                                        X_ATTRIBUTE11         => NULL,
                                        X_ATTRIBUTE12         => NULL,
                                        X_ATTRIBUTE13         => NULL,
                                        X_ATTRIBUTE14         => NULL,
                                        X_ATTRIBUTE15         => NULL,
                                        X_CREATION_DATE       => SYSDATE,
                                        X_CREATED_BY          => gn_user_id,
                                        X_LAST_UPDATE_DATE    => SYSDATE,
                                        X_LAST_UPDATED_BY     => gn_user_id,
                                        X_LAST_UPDATE_LOGIN   => gn_login_id);
                                END IF;

                                print_msg_prc (
                                    p_debug   => gc_debug_flag,
                                    p_message   =>
                                           'create document for l_rule_element_id  END IF=> '
                                        || l_rule_element_id);
                            --                      END IF; -- ln_rule_id = 0

                            END IF;                --nvl(ln_document_id,0) > 0
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                print_msg_prc (
                                    p_debug   => 'Y',
                                    p_message   =>
                                           'create OE_ATT_RULE_ELEMENTS_PKG for ln_rule_id  last=> '
                                        || SQLERRM);
                            WHEN OTHERS
                            THEN
                                print_msg_prc (
                                    p_debug   => 'Y',
                                    p_message   =>
                                           'create OE_ATT_RULE_ELEMENTS_PKG for ln_rule_id  last=> '
                                        || SQLERRM);
                        END;
                    END IF;      --  ln_category_id = 0 and ln_document_id = 0
                END IF;                     --  ln_attribute_value IS NOT NULL

                --get rowid to pass back to form
                OPEN C;

                FETCH C INTO ln_rowid;

                IF (C%NOTFOUND)
                THEN
                    ROLLBACK;

                    UPDATE XXD_SO_DOCUMENT_ATTACHMENTS_T
                       SET RECORD_STATUS   = gc_error_status
                     WHERE record_id = so_doc_rec.record_id;
                ELSE
                    UPDATE XXD_SO_DOCUMENT_ATTACHMENTS_T
                       SET RECORD_STATUS   = gc_process_status
                     WHERE record_id = so_doc_rec.record_id;

                    COMMIT;
                END IF;

                CLOSE C;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    print_msg_prc (
                        p_debug     => 'Y',
                        p_message   => 'create LOOP for   last=> ' || SQLERRM);
                WHEN OTHERS
                THEN
                    print_msg_prc (
                        p_debug     => 'Y',
                        p_message   => 'create LOOP for   last=> ' || SQLERRM);
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SUBSTR (SQLERRM, 1, 250);
            retcode   := 2;
            print_msg_prc (p_debug => 'Y', p_message => 'errbuf => ' || errbuf);
    END so_doc_attachment_main;
END XXD_SO_DOC_ATTACHMENTS_PKG;
/
