--
-- XXDO_OEXPRPRD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:32 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxdo_oexprprd_pkg
IS
    FUNCTION AfterPForm (P_ORDER_NUM_LOW        IN NUMBER,
                         P_ORDER_NUM_HIGH       IN NUMBER,
                         P_CUSTOMER_NAME_LOW    IN VARCHAR2,
                         P_CUSTOMER_NUM_LOW     IN VARCHAR2,
                         P_ORDER_DATE_LOW       IN VARCHAR2,
                         P_ORDER_DATE_HIGH      IN VARCHAR2,
                         P_ORDER_TYPE_LOW       IN VARCHAR2,
                         P_ORDER_TYPE_HIGH      IN VARCHAR2,
                         P_LINE_TYPE_LOW        IN VARCHAR2,
                         P_LINE_TYPE_HIGH       IN VARCHAR2,
                         P_ITEM_LOW             IN VARCHAR2,
                         P_SALESREP_LOW         IN VARCHAR2,
                         P_SORT_BY              IN VARCHAR2,
                         P_CUSTOMER_NAME_HIGH   IN VARCHAR2,
                         P_CUSTOMER_NUM_HIGH1   IN VARCHAR2,
                         P_ITEM_HI              IN VARCHAR2,
                         P_SALESREP_HIGH        IN VARCHAR2,
                         P_OPEN_FLAG            IN VARCHAR2,
                         P_ORDER_CATEGORY       IN VARCHAR2,
                         P_LINE_CATEGORY        IN VARCHAR2,
                         P_BRAND                IN VARCHAR2,
                         P_ITEM_NUMBER          IN VARCHAR2,
                         p_operating_unit       IN VARCHAR2)
        RETURN BOOLEAN
    IS
        BLANKS      CONSTANT VARCHAR2 (5) := '     ';
        all_range   CONSTANT VARCHAR2 (16)
                                 := 'From' || BLANKS || 'To' || BLANKS ;
    BEGIN
        apps.fnd_client_info.set_org_context (p_operating_unit);

        --mo_global.init ('PA');
        --      apps.fnd_file.put_line (fnd_file.LOG, 'Begin ' || lp_where_clause);

        -- GENERATE ORDER NUMBER LEXICAL
        IF (p_operating_unit IS NOT NULL)
        THEN
            lp_operating_unit   :=
                ' AND (H.ORG_ID =''' || p_operating_unit || ''') ';
        END IF;

        IF (P_ITEM_NUMBER IS NOT NULL)
        THEN
            lp_item_number   :=
                ' AND (L.INVENTORY_ITEM_ID =''' || P_ITEM_NUMBER || ''') ';
        END IF;

        IF (P_BRAND IS NOT NULL)
        THEN
            lp_brand   := ' AND (h.attribute5 =''' || P_BRAND || ''') ';
        END IF;

        IF (p_order_num_low IS NOT NULL) AND (p_order_num_high IS NOT NULL)
        THEN
            -- GENERATE LEXICAL

            lp_order_num   :=
                   'AND ( H.ORDER_NUMBER  BETWEEN '''
                || p_order_num_low
                || ''' AND '''
                || p_order_num_high
                || '''  )';
        -- lp_order_num := NULL;
        ELSIF (p_order_num_low IS NOT NULL)
        THEN
            -- GENERATE LEXICAL
            lp_order_num   :=
                   ' AND (H.ORDER_NUMBER >='''
                || TO_NUMBER (p_order_num_low)
                || ''')';
        ELSIF (p_order_num_high IS NOT NULL)
        THEN
            -- GENERATE LEXICAL
            lp_order_num   :=
                   ' AND (H.ORDER_NUMBER <='''
                || TO_NUMBER (p_order_num_high)
                || ''')';
        ELSE
            order_number_parms        := all_range;
            -- Changes for Pseudo Translation
            order_number_parms_low    := BLANKS;
            order_number_parms_high   := BLANKS;
        END IF;

        -- GENERATE CUSTOMER NAME LEXICAL
        IF     (p_customer_name_low IS NOT NULL)
           AND (p_customer_name_high IS NOT NULL)
        THEN
            -- GENERATE LEXICAL
            lp_customer_name   :=
                   'AND (ORG.NAME BETWEEN '''
                || P_CUSTOMER_NAME_LOW
                || ''' AND '''
                || P_CUSTOMER_NAME_HIGH
                || '''  )';
        ELSIF (p_customer_name_low IS NOT NULL)
        THEN
            -- GENERATE LEXICAL
            lp_customer_name   :=
                ' AND (ORG.NAME >=''' || P_CUSTOMER_NAME_LOW || ''')';
        ELSIF (p_customer_name_high IS NOT NULL)
        THEN
            -- GENERATE LEXICAL
            lp_customer_name   :=
                ' AND (ORG.NAME <=''' || P_CUSTOMER_NAME_HIGH || ''')';
        ELSE
            customer_parms        := all_range;
            -- Changes for Pseudo Translation
            customer_parms_low    := BLANKS;
            customer_parms_high   := BLANKS;
        END IF;

        -- GENERATE CUSTOMER NUMBER LEXICAL
        IF     (p_customer_num_low IS NOT NULL)
           AND (p_customer_num_high1 IS NOT NULL)
        THEN
            -- GENERATE LEXICAL
            lp_customer_num   :=
                   'AND (ORG.CUSTOMER_NUMBER BETWEEN '''
                || P_CUSTOMER_NUM_LOW
                || ''' AND '''
                || P_CUSTOMER_NUM_HIGH1
                || '''  )';
        ELSIF (p_customer_num_low IS NOT NULL)
        THEN
            -- GENERATE LEXICAL
            lp_customer_num   :=
                   ' AND (ORG.CUSTOMER_NUMBER >='''
                || P_CUSTOMER_NUM_LOW
                || ''')';
        ELSIF (p_customer_num_high1 IS NOT NULL)
        THEN
            -- GENERATE LEXICAL
            lp_customer_num   :=
                   ' AND (ORG.CUSTOMER_NUMBER <='''
                || P_CUSTOMER_NUM_HIGH1
                || ''')';
        ELSE
            customer_num_parms        := all_range;
            -- Changes for Pseudo Translation
            customer_num_parms_low    := BLANKS;
            customer_num_parms_high   := BLANKS;
        END IF;

        -- GENERATE ORDER DATE LEXICAL
        IF (p_order_date_low IS NOT NULL) AND (p_order_date_high IS NOT NULL)
        THEN
            -- GENERATE LEXICAL
            /* lp_order_date :=
                   ' AND (trunc(H.ORDERED_DATE) BETWEEN'
                || ' P_ORDER_DATE_LOW AND'
                || ' P_ORDER_DATE_HIGH) ';*/
            --lp_order_date := null;
            lp_order_date   :=
                   ' AND (trunc(H.ORDERED_DATE) BETWEEN to_date('''
                || P_ORDER_DATE_LOW
                || ''',''YYYY-MM-DD HH24:MI:SS'') AND  to_date('''
                || P_ORDER_DATE_HIGH
                || ''',''YYYY-MM-DD HH24:MI:SS'' ))';
        ELSIF (p_order_date_low IS NOT NULL)
        THEN
            -- GENERATE LEXICAL
            lp_order_date   :=
                   ' AND (trunc(H.ORDERED_DATE) >= to_date('''
                || P_ORDER_DATE_LOW
                || ''',''YYYY-MM-DD HH24:MI:SS''))';
        ELSIF (p_order_date_high IS NOT NULL)
        THEN
            -- GENERATE LEXICAL
            lp_order_date   :=
                   ' AND (trunc(H.ORDERED_DATE) >= to_date('''
                || p_order_date_high
                || ''',''YYYY-MM-DD HH24:MI:SS''))';
        ELSE
            order_date_parms        := all_range;
            -- Changes for Pseudo Translation
            order_date_parms_low    := BLANKS;
            order_date_parms_high   := BLANKS;
        END IF;

        -- GENERATE ORDER TYPE LEXICAL
        IF (p_order_type_low IS NOT NULL) AND (p_order_type_high IS NOT NULL)
        THEN
            -- GENERATE LEXICAL
            lp_order_type   :=
                   'AND (OT.transaction_type_id BETWEEN '''
                || P_ORDER_TYPE_LOW
                || ''' AND '''
                || P_ORDER_TYPE_HIGH
                || '''  )';

            SELECT oeot.NAME
              INTO l_order_type_low
              FROM oe_transaction_types_tl oeot
             WHERE     oeot.transaction_type_id = p_order_type_low
                   AND oeot.LANGUAGE = USERENV ('LANG');

            SELECT oeot.NAME
              INTO l_order_type_high
              FROM oe_transaction_types_tl oeot
             WHERE     oeot.transaction_type_id = p_order_type_high
                   AND oeot.LANGUAGE = USERENV ('LANG');
        ELSIF (p_order_type_low IS NOT NULL)
        THEN
            -- GENERATE LEXICAL
            lp_order_type   :=
                   ' AND (OT.transaction_type_id >='''
                || P_ORDER_TYPE_LOW
                || ''')';

            SELECT oeot.NAME
              INTO l_order_type_low
              FROM oe_transaction_types_tl oeot
             WHERE     oeot.transaction_type_id = p_order_type_low
                   AND oeot.LANGUAGE = USERENV ('LANG');
        ELSIF (p_order_type_high IS NOT NULL)
        THEN
            -- GENERATE LEXICAL
            lp_order_type   :=
                   ' AND (OT.transaction_type_id <='''
                || P_ORDER_TYPE_HIGH
                || ''')';

            SELECT oeot.NAME
              INTO l_order_type_high
              FROM oe_transaction_types_tl oeot
             WHERE     oeot.transaction_type_id = p_order_type_high
                   AND oeot.LANGUAGE = USERENV ('LANG');
        ELSE
            order_type_parms        := all_range;
            -- Changes for Pseudo Translation
            order_type_parms_low    := BLANKS;
            order_type_parms_high   := BLANKS;
        END IF;

        --Bug 4657429

        IF (p_line_type_low IS NOT NULL)
        THEN
            SELECT oeot.NAME
              INTO l_line_type_low
              FROM oe_transaction_types_tl oeot
             WHERE     oeot.transaction_type_id = p_line_type_low
                   AND oeot.LANGUAGE = USERENV ('LANG');
        END IF;

        IF (p_line_type_high IS NOT NULL)
        THEN
            SELECT oeot.NAME
              INTO l_line_type_high
              FROM oe_transaction_types_tl oeot
             WHERE     oeot.transaction_type_id = p_line_type_high
                   AND oeot.LANGUAGE = USERENV ('LANG');
        END IF;

        -- GENERATE ITEM
        IF (p_item_low IS NOT NULL) AND (p_item_hi IS NOT NULL)
        THEN
            --srw.message(1,'P_ITEM_LOW'||P_ITEM_LOW);
            -- GENERATE STRING TO PRINT
            line_type_parms        :=
                   'From '
                || SUBSTR (l_line_type_low, 1, 16)
                || ' To '
                || SUBSTR (l_line_type_high, 1, 16);
            -- Changes for Pseudo Translation
            line_type_parms_low    := SUBSTR (l_line_type_low, 1, 16);
            line_type_parms_high   := SUBSTR (l_line_type_high, 1, 16);
        ELSIF (p_item_low IS NOT NULL)
        THEN
            -- GENERATE STRING TO PRINT
            line_type_parms        :=
                'From ' || SUBSTR (p_item_low, 1, 16) || ' To ' || BLANKS;
            -- Changes for Pseudo Translation
            line_type_parms_low    := SUBSTR (p_item_low, 1, 16);
            line_type_parms_high   := BLANKS;
        ELSIF (p_item_hi IS NOT NULL)
        THEN
            -- GENERATE STRING TO PRINT
            line_type_parms        :=
                'From ' || BLANKS || 'To ' || SUBSTR (p_item_hi, 1, 16);
            -- Changes for Pseudo Translation
            line_type_parms_low    := BLANKS;
            line_type_parms_high   := SUBSTR (p_item_hi, 1, 16);
        ELSE
            line_type_parms        := all_range;
            -- Changes for Pseudo Translation
            line_type_parms_low    := BLANKS;
            line_type_parms_high   := BLANKS;
        END IF;

        -- GENERATE SALES REPRESENTATIVE LEXICAL
        IF (p_salesrep_low IS NOT NULL) AND (p_salesrep_high IS NOT NULL)
        THEN
            -- GENERATE LEXICAL

            lp_salesrep   :=
                   'AND (SR.NAME BETWEEN '''
                || p_salesrep_low
                || ''' AND '''
                || p_salesrep_high
                || '''  )';
        ELSIF (p_salesrep_low IS NOT NULL)
        THEN
            lp_salesrep   := ' AND (SR.NAME >= ''' || p_salesrep_low || ''')';
        ELSIF (p_salesrep_high IS NOT NULL)
        THEN
            -- GENERATE LEXICAL
            --Bug 7258102
            /*LP_SALESREP := ' AND H.SALESREP_ID <=' ||
                            ' P_SALESREP_HIGH ';*/
            lp_salesrep   :=
                ' AND (SR.NAME >= ''' || p_salesrep_high || ''')';
        ELSE
            salesrep_parms        := all_range;
            -- Changes for Pseudo Translation
            salesrep_parms_low    := BLANKS;
            salesrep_parms_high   := BLANKS;
        END IF;

        -- GENERATE SORT BY LEXICAL
        IF (p_sort_by IS NOT NULL)
        THEN
            IF (p_sort_by = 'CUSTOMER')
            THEN
                lp_sort_by   := ' ORG.NAME, ';
            ELSIF (p_sort_by = 'ORDER_NUMBER')
            THEN
                lp_sort_by   := ' H.ORDER_NUMBER, ';
            ELSIF (p_sort_by = 'ITEM')
            THEN
                lp_sort_by   := ' SI.SEGMENT1, ';
            END IF;
        ELSE
            -- DEFAULT IS SORT BY ORDER NUMBER
            lp_sort_by   := ' H.ORDER_NUMBER, ';
        END IF;

        -- GENERATE OPEN FLAG LEXICAL
        IF (p_open_flag IS NOT NULL)
        THEN
            -- GENERATE LEXICAL
            IF ((SUBSTR (UPPER (p_open_flag), 1, 1)) = 'Y')
            THEN
                lp_open_flag   := ' AND H.OPEN_FLAG = ''Y''';
            -- Changed for bug#2681801
            ELSE
                lp_open_flag   := ' AND H.OPEN_FLAG IS NOT NULL';
            -- Added for bug#2681801
            END IF;
        END IF;

        /*  -- GENERATE ORDER CATEGORY LEXICAL
          IF P_ORDER_CATEGORY IS NOT NULL THEN
          LP_ORDER_CATEGORY := 'AND H.ORDER_CATEGORY := P_ORDER_CATEGORY';
          ELSE
          LP_ORDER_CATEGORY := 'AND H.ORDER_CATEGORY IN (''R'',''P'')';
          END IF;
        */

        -- GENERATE ORDER CATEGORY LEXICAL
        IF p_order_num_low = p_order_num_high
        THEN
            NULL;
        ELSE
            IF p_order_category IS NOT NULL
            THEN
                IF p_order_category = 'SALES'
                THEN
                    lp_order_category   :=
                        ' and h.order_category_code in (''ORDER'', ''MIXED'') ';
                ELSIF p_order_category = 'CREDIT'
                THEN
                    lp_order_category   :=
                        ' and h.order_category_code in (''RETURN'', ''MIXED'') ';
                ELSIF p_order_category = 'ALL'
                THEN
                    lp_order_category   := NULL;
                END IF;
            ELSE
                lp_order_category   :=
                    ' and h.order_category_code in (''ORDER'', ''MIXED'') ';
            END IF;
        END IF;

        -- GENERATE LINE CATEGORY LEXICAL
        IF p_line_category IS NOT NULL
        THEN
            IF p_line_category = 'SALES'
            THEN
                lp_line_category   :=
                    ' and l.line_category_code = ''ORDER'' ';
            ELSIF p_line_category = 'CREDIT'
            THEN
                lp_line_category   :=
                    ' and l.line_category_code = ''RETURN'' ';
            ELSIF p_line_category = 'ALL'
            THEN
                lp_line_category   := NULL;
            END IF;
        ELSE
            lp_line_category   := ' and l.line_category_code = ''ORDER'' ';
        END IF;

        lp_where_clause   :=
               lp_open_flag
            || ' '
            || lp_salesrep
            || ' '
            || lp_order_date
            || ' '
            || lp_order_type
            || ' '
            || lp_customer_name
            || ' '
            || lp_order_num
            || ' '
            || lp_line_type
            || ' '
            || lp_customer_num
            || ' '
            || lp_order_category
            || ' '
            || lp_item
            || ' '
            || lp_line_category
            || ' '
            || lp_brand
            || ' '
            || lp_item_number
            || ' '
            || lp_operating_unit;
        apps.fnd_file.put_line (fnd_file.LOG,
                                'Where Clause is ' || lp_where_clause);
        RETURN (TRUE);
    END;
END xxdo_oexprprd_pkg;
/
