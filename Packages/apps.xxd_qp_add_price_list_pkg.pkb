--
-- XXD_QP_ADD_PRICE_LIST_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:23 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_QP_ADD_PRICE_LIST_PKG"
AS
    -- global variable
    g_dbg_mode               VARCHAR2 (10) := 'CONC';
    g_log_file               UTL_FILE.file_type;
    g_status                 VARCHAR2 (10);
    g_temp                   BOOLEAN;
    g_freight_param          VARCHAR2 (1);
    g_duty_param             VARCHAR2 (1);
    g_dutiable_oh_param      VARCHAR2 (1);
    g_nondutiable_oh_param   VARCHAR2 (1);
    g_precision              NUMBER;
    g_markup                 NUMBER;
    g_ex_rate                NUMBER;

    -- ---------------------------------------------------------------------------------------------
    --
    -- History:
    -- 11-JUL-2013  Bill Simpson  CCR0003082   Currently price is rounded to 2 decimal places for ALL target price lists.
    --                                         With this change, the rounding factor will be set to the precision of the
    --                                         target PRICE LIST CURRENCY  (ex: USD = 2, CAD = 2, EUR = 2, JPY = 0)
    --                                         This came up because Deckers is starting to use this utility to populate a JPY
    --                                         price list which has a 0 decimal precision (all have been 2 decimals up until this point)
    --
    -- 27-Oct-2014  BT Technology Team         Redesign for Business Transformation
    -- 25-Mar-2016  BT Technology Team         Used the max list line id instead of checking by date range
    --                                         to get the latest line
    -- 26-Jul-2016  Kranthi Bollam             Replaced the query to get category_id for style in GET_PRODUCT_VALUE function
    --                                         Commented the date condition in cur_price_list_update cursor in xxdoqp_populate_pricelist procedure and
    --                                         replaced it with SEASON condition
    -- ---------------------------------------------------------------------------------------------

    --  PROCEDURE write_out (p_in IN VARCHAR2 DEFAULT ' '); -- Commented by BT Technology Team on 27-Oct-2014

    -- Procedure added by BT Technology Team on 27-Oct-2014
    PROCEDURE print_log (p_msg VARCHAR2)
    IS
    BEGIN
        -- fnd_file.put_line (fnd_file.LOG, p_msg);
        DBMS_OUTPUT.put_line (p_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'error While writing into log file ');
    END print_log;

    /*****************************************************************************************
     *  Function Name :   Get_Product_Value                                                  *
     *                                                                                       *
     *  Description    :   This Function shall Returns the Item or item category details     *
     *                                                                                       *
     *                                                                                       *
     *                                                                                       *
     *  Called From    :   Concurrent Program                                                *
     *                                                                                       *
     *  Parameters             Type       Description                                        *
     *  -----------------------------------------------------------------------------        *
     *  p_FlexField_Name          IN      Constant 'QP_ATTR_DEFNS_PRICING'                   *
     *  p_Context_Name            IN      Constant 'ITEM'                                    *
     *  p_attribute_name          IN      PRICING_ATTRIBUTE1,PRICING_ATTRIBUTE2              *
     *  p_attr_value              IN      ID from the 1206 system                            *
     *                                                                                       *
     * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
     *                                                                                       *
      *****************************************************************************************/

    FUNCTION Get_Product_Value (p_FlexField_Name IN VARCHAR2, p_Context_Name IN VARCHAR2, p_attribute_name IN VARCHAR2
                                , p_attr_value IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_item_id           NUMBER := NULL;
        l_category_id       NUMBER := NULL;
        l_segment_name      VARCHAR2 (240) := NULL;
        l_organization_id   VARCHAR2 (30)
                                := TO_CHAR (QP_UTIL.Get_Item_Validation_Org);
    BEGIN
        IF ((p_FlexField_Name = 'QP_ATTR_DEFNS_PRICING') AND (p_Context_Name = 'ITEM'))
        THEN
            IF (p_attribute_name = 'PRICING_ATTRIBUTE1')
            THEN
                SELECT inventory_item_id
                  INTO l_item_id
                  FROM mtl_system_items_vl
                 WHERE concatenated_segments = p_attr_value --            and organization_id = l_organization_id
                                                            AND ROWNUM = 1;


                RETURN l_item_id;
            ELSIF (p_attribute_name = 'PRICING_ATTRIBUTE2')
            THEN
                --              select category_name
                --                    into x_category_name
                --                    from qp_item_categories_v@BT_READ_1206
                --                    where category_id = to_number(p_attr_value) and rownum=1;


                BEGIN
                    --Commented the below code on 26Jul2016
                    /*
                    SELECT category_id
                      INTO l_category_id
                      FROM qp_item_categories_v
                     WHERE category_name = TRIM (p_attr_value)
                       AND ROWNUM = 1;
                   */

                    --Added the below select stmt on 26Jul2016
                    SELECT price_cat.category_id                -- Category_id
                      INTO l_category_id
                      FROM mtl_categories_v item_cat, mtl_categories_v price_cat
                     WHERE     1 = 1
                           AND item_cat.structure_name = 'Item Categories'
                           AND price_cat.structure_name =
                               'PriceList Item Categories'
                           AND item_cat.segment7 = price_cat.segment1 --Style Description
                           AND item_cat.attribute7 = TO_CHAR (p_attr_value) --Style_number
                           AND ROWNUM = 1;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        NULL;
                    WHEN OTHERS
                    THEN
                        NULL;
                END;


                RETURN l_category_id;
            --
            ELSE
                l_segment_name   :=
                    QP_PRICE_LIST_LINE_UTIL.Get_Segment_Name (
                        p_FlexField_Name,
                        p_Context_Name,
                        p_attribute_name);

                RETURN (QP_PRICE_LIST_LINE_UTIL.Get_Attribute_Value (
                            p_FlexField_Name,
                            p_Context_Name,
                            l_segment_name,
                            p_attr_value));
            --
            END IF;
        ELSE
            RETURN NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END Get_Product_Value;

    PROCEDURE write_out (p_in IN VARCHAR2 DEFAULT ' ')
    IS
    BEGIN
        IF (g_dbg_mode = 'CONC')
        THEN
            -- write to the concurrent request output file
            fnd_file.put_line (fnd_file.output, p_in);
        ELSIF (g_dbg_mode = 'FILE')
        THEN
            UTL_FILE.put_line (g_log_file, p_in);
            UTL_FILE.fflush (g_log_file);
        ELSE
            print_log (p_in);    -- Added by BT Technology Team on 27-Oct-2014
        END IF;
    END write_out;

    -- Start Changes by BT Technology Team on 27-Oct-2014


    PROCEDURE print_out (p_msg VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.output, p_msg);
        DBMS_OUTPUT.put_line (p_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'error While writing into log file ');
    END print_out;

    FUNCTION get_item_cost (it_cost NUMBER, fr_cost NUMBER, dt_cost NUMBER,
                            oh_duty_cost NUMBER, oh_non_duty_cost NUMBER)
        RETURN NUMBER
    IS
        item_cost         NUMBER;
        final_item_cost   NUMBER;
    BEGIN
        item_cost   := it_cost;

        IF g_freight_param = 'N'
        THEN
            item_cost   := item_cost - fr_cost;
        END IF;

        IF g_duty_param = 'N'
        THEN
            item_cost   := item_cost - dt_cost;
        END IF;

        IF g_dutiable_oh_param = 'N'
        THEN
            item_cost   := item_cost - oh_duty_cost;
        END IF;

        IF g_nondutiable_oh_param = 'N'
        THEN
            item_cost   := item_cost - oh_non_duty_cost;
        END IF;

        final_item_cost   :=
            ROUND (
                ((item_cost * NVL (g_ex_rate, 1)) + ((item_cost * NVL (g_ex_rate, 1)) * NVL (g_markup / 100, 0))),
                g_precision);
        RETURN final_item_cost;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('ERROR ' || SQLERRM);
            RETURN NULL;
    END get_item_cost;

    PROCEDURE insert_price_list (
        p_price_list_rec        IN     apps.qp_price_list_pub.price_list_rec_type,
        p_price_list_line_tbl   IN     apps.qp_price_list_pub.price_list_line_tbl_type,
        p_pricing_attr_tbl      IN     apps.qp_price_list_pub.pricing_attr_tbl_type,
        x_return_status            OUT VARCHAR2,
        x_error_message            OUT VARCHAR2)
    IS
        c_return_status             VARCHAR2 (20000);
        c_error_data                VARCHAR2 (20000);
        n_msg_count                 NUMBER;
        c_msg_data                  VARCHAR2 (20000);
        n_err_count                 NUMBER;
        l_qualifiers_tbl            apps.qp_qualifier_rules_pub.qualifiers_tbl_type;
        x_price_list_rec            apps.qp_price_list_pub.price_list_rec_type;
        l_price_list_val_rec        apps.qp_price_list_pub.price_list_val_rec_type;
        x_price_list_val_rec        apps.qp_price_list_pub.price_list_val_rec_type;
        x_price_list_line_tbl       apps.qp_price_list_pub.price_list_line_tbl_type;
        x_price_list_line_val_tbl   apps.qp_price_list_pub.price_list_line_val_tbl_type;
        l_price_list_line_val_tbl   apps.qp_price_list_pub.price_list_line_val_tbl_type;
        x_qualifiers_tbl            apps.qp_qualifier_rules_pub.qualifiers_tbl_type;
        x_qualifiers_val_tbl        apps.qp_qualifier_rules_pub.qualifiers_val_tbl_type;
        l_qualifiers_val_tbl        apps.qp_qualifier_rules_pub.qualifiers_val_tbl_type;
        x_pricing_attr_tbl          apps.qp_price_list_pub.pricing_attr_tbl_type;
        x_pricing_attr_val_tbl      apps.qp_price_list_pub.pricing_attr_val_tbl_type;
        l_pricing_attr_val_tbl      apps.qp_price_list_pub.pricing_attr_val_tbl_type;
    BEGIN
        x_error_message   := NULL;
        oe_msg_pub.Initialize;

        --g_process_ind := 11;
        qp_price_list_pub.process_price_list (
            p_api_version_number        => 1.0,
            p_init_msg_list             => fnd_api.g_false,
            p_return_values             => fnd_api.g_false,
            p_commit                    => fnd_api.g_false,
            x_return_status             => c_return_status,
            x_msg_count                 => n_msg_count,
            x_msg_data                  => c_msg_data,
            p_price_list_rec            => p_price_list_rec,
            p_price_list_val_rec        => l_price_list_val_rec,
            p_price_list_line_tbl       => p_price_list_line_tbl,
            p_price_list_line_val_tbl   => l_price_list_line_val_tbl,
            p_qualifiers_tbl            => l_qualifiers_tbl,
            p_qualifiers_val_tbl        => l_qualifiers_val_tbl,
            p_pricing_attr_tbl          => p_pricing_attr_tbl,
            p_pricing_attr_val_tbl      => l_pricing_attr_val_tbl,
            x_price_list_rec            => x_price_list_rec,
            x_price_list_val_rec        => x_price_list_val_rec,
            x_price_list_line_tbl       => x_price_list_line_tbl,
            x_price_list_line_val_tbl   => x_price_list_line_val_tbl,
            x_qualifiers_tbl            => x_qualifiers_tbl,
            x_qualifiers_val_tbl        => x_qualifiers_val_tbl,
            x_pricing_attr_tbl          => x_pricing_attr_tbl,
            x_pricing_attr_val_tbl      => x_pricing_attr_val_tbl);

        x_return_status   := c_return_status;

        IF (c_return_status <> fnd_api.g_ret_sts_success)
        THEN
            ROLLBACK;
            oe_msg_pub.count_and_get (p_count   => n_err_count,
                                      p_data    => c_error_data);
            c_error_data   := NULL;

            FOR i IN 1 .. n_err_count
            LOOP
                c_msg_data   :=
                    oe_msg_pub.get (p_msg_index   => oe_msg_pub.g_next,
                                    p_encoded     => fnd_api.g_false);
                c_error_data   :=
                    SUBSTR (c_error_data || c_msg_data, 1, 2000);
            END LOOP;

            x_error_message   :=
                'Error in Prepare_end_date_prc :' || c_error_data;
        ELSE
            COMMIT;
        END IF;
    END insert_price_list;

    FUNCTION get_price_list_cost (p_price_list_id   NUMBER,
                                  p_inv_item_id     NUMBER)
        RETURN NUMBER
    AS
        l_list_price   NUMBER;
    BEGIN
        SELECT qll.operand
          INTO l_list_price
          FROM qp_list_lines qll, qp_pricing_attributes qpa
         WHERE     qll.list_header_id = p_price_list_id
               AND qll.list_line_id = qpa.list_line_id
               AND qpa.product_attr_value = TO_CHAR (p_inv_item_id)
               AND qll.list_line_type_code = 'PLL'
               AND TRUNC (SYSDATE) BETWEEN NVL (qll.start_date_active,
                                                SYSDATE - 1)
                                       AND NVL (qll.end_date_active,
                                                SYSDATE + 1);

        RETURN (l_list_price);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            print_log (
                   'inventory item id : '
                || p_inv_item_id
                || ' not found on pricelist :'
                || p_price_list_id);
            l_list_price   := 0;
            RETURN (l_list_price);
        WHEN OTHERS
        THEN
            l_list_price   := 0;
            RETURN (l_list_price);
    END get_price_list_cost;

    PROCEDURE UPDATE_STATUS (p_status IN VARCHAR2, p_error_message IN VARCHAR2, p_price_list_name IN VARCHAR2
                             , p_product_context IN VARCHAR2, p_product_attribute IN VARCHAR2, p_product_value IN VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        UPDATE xxd_qp_add_price_list_tbl xpap
           SET status = p_status, error_message = p_error_message
         WHERE     xpap.price_list_name = p_price_list_name
               AND xpap.product_context = p_product_context
               AND xpap.product_attribute = p_product_attribute
               AND xpap.product_value = p_product_value;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'exception while updating status' || SQLERRM);
    END UPDATE_STATUS;

    -- End Changes by BT Technology Team on 27-Oct-2014
    PROCEDURE xxdoqp_populate_pricelist (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_purge_days IN NUMBER --Added on 26Jul2016 for purge logic
                                                                                                          )
    IS
        nrec                         qp_list_lines%ROWTYPE;
        new_list_line_number         NUMBER;
        attr_group_no                NUMBER;
        l_currency_precision         NUMBER;
        -- Start changes by BT Technology Team on 27-Oct-2014
        l_price_list_rec             qp_price_list_pub.price_list_rec_type;
        l_price_list_line_tbl        qp_price_list_pub.price_list_line_tbl_type;
        l_qualifiers_tbl             qp_qualifier_rules_pub.qualifiers_tbl_type;
        l_pricing_attr_tbl           qp_price_list_pub.pricing_attr_tbl_type;
        k                            NUMBER := 1;
        l_return_status              VARCHAR2 (4000) := NULL;
        l_msg_data                   VARCHAR2 (20000);
        l_price_list_rec1            apps.qp_price_list_pub.price_list_rec_type;
        l_price_list_line_tbl1       apps.qp_price_list_pub.price_list_line_tbl_type;
        l_pricing_attr_tbl1          apps.qp_price_list_pub.pricing_attr_tbl_type;
        x_price_list_rec1            apps.qp_price_list_pub.price_list_rec_type;
        x_price_list_val_rec1        apps.qp_price_list_pub.price_list_val_rec_type;
        x_price_list_line_tbl1       apps.qp_price_list_pub.price_list_line_tbl_type;
        x_price_list_line_val_tbl1   apps.qp_price_list_pub.price_list_line_val_tbl_type;
        x_qualifiers_tbl1            apps.qp_qualifier_rules_pub.qualifiers_tbl_type;
        x_qualifiers_val_tbl1        apps.qp_qualifier_rules_pub.qualifiers_val_tbl_type;
        x_pricing_attr_tbl1          apps.qp_price_list_pub.pricing_attr_tbl_type;
        x_pricing_attr_val_tbl1      apps.qp_price_list_pub.pricing_attr_val_tbl_type;
        q                            NUMBER := 1;
        l_return_status1             VARCHAR2 (20000) := NULL;
        l_msg_data1                  VARCHAR2 (20000);
        s                            NUMBER := 1;
        t                            NUMBER := 1;
        l_return_status2             VARCHAR2 (1) := NULL;
        l_msg_count2                 NUMBER := 0;
        l_msg_data2                  VARCHAR2 (4000);
        l_product_value              VARCHAR2 (100);

        CURSOR cur_error_rpt IS
            SELECT *
              FROM xxd_qp_add_price_list_tbl
             WHERE status = 'E' AND TRUNC (creation_date) = TRUNC (SYSDATE);

        CURSOR cur_price_list_add IS
            SELECT qph.list_header_id,
                   xpap.valid_from_date,
                   xpap.valid_to_date,
                   xpap.price,
                   xpap.uom,
                   UPPER (xpap.brand) brand,
                   UPPER (xpap.season) season,
                   xpap.record_status,
                   xpap.product_context,
                   xpap.product_attribute,
                   xpap.price_list_name,
                   XPAP.product_value product_val,
                   Get_Product_Value ('QP_ATTR_DEFNS_PRICING', xpap.product_context, xpap.product_attribute
                                      , xpap.product_value) product_value
              FROM QP_LIST_HEADERS_all QPH, XXD_QP_ADD_PRICE_LIST_TBL xpap
             WHERE     qph.name = xpap.price_list_name
                   AND xpap.status = 'N'
                   AND NVL (UPPER (xpap.record_status), 'UPDATE') = 'ADD';

        CURSOR cur_line_det (p_list_header_id      IN NUMBER,
                             p_product_context     IN VARCHAR2,
                             p_product_attribute   IN VARCHAR2,
                             p_product_attr_val    IN VARCHAR2-- Code change on 27-Jul-2016
                                                              ,
                             p_uom                 IN VARCHAR2-- End of Code change on 27-Jul-2016
                                                              )
        IS
              SELECT --qpll.list_line_id, commented by BT Tech team on 25-Mar-2016 for date overlap issue
                     MAX (qpll.list_line_id) list_line_id, -- Added by BT Tech team on 25-Mar-2016 for date overlap issue
                                                           qppr.product_attribute_datatype
                -- qppr.product_attr_value product_value
                FROM qp_list_lines qpll, qp_pricing_attributes qppr
               WHERE     qppr.list_line_id = qpll.list_line_id
                     AND qpll.list_header_id = p_list_header_id
                     AND qpll.list_line_type_code = 'PLL'
                     AND qppr.product_attribute_context = p_product_context
                     AND qppr.product_attribute = p_product_attribute
                     AND qppr.product_attr_value = p_product_attr_val
                     -- Code change on 27-Jul-2016
                     AND qppr.product_uom_code = p_uom
            -- End of Code change on 27-Jul-2016
            -- Commented below by BT Tech team on 25-Mar-2016 for date overlap issue
            /*  AND TRUNC (SYSDATE) BETWEEN NVL (qpll.start_date_active,
                                                   SYSDATE - 1)
                                          AND NVL (qpll.end_date_active,
                                                   SYSDATE + 1);   */
            -- Commented above by BT Tech team on 25-Mar-2016 for date overlap issue
            GROUP BY qppr.product_attribute_datatype; -- Added by BT Tech team on 25-Mar-2016 for date overlap issue


        CURSOR cur_price_list_update IS
            SELECT *
              FROM (SELECT qph.list_header_id, qll.list_line_id, --xpap.valid_from_date,--Commented on 26Jul2016
                                                                 --NVL (xpap.valid_to_date, SYSDATE) valid_to_date,--Commented on 26Jul2016
                                                                 xpap.price,
                           xpap.uom, UPPER (xpap.brand) brand, UPPER (xpap.season) season,
                           xpap.record_status, xpap.PRODUCT_CONTEXT, xpap.PRODUCT_ATTRIBUTE,
                           xpap.price_list_name, xpap.product_value product_val, qll.product_attr_value product_value,
                           DENSE_RANK () OVER (PARTITION BY xpap.season, qph.list_header_id, xpap.product_value ORDER BY qll.list_line_id DESC) my_rank
                      FROM qp_list_lines_v qll, qp_pricing_attributes qpa, QP_LIST_HEADERS_all QPH,
                           qp_list_headers_tl qpt, xxd_qp_add_price_list_tbl xpap
                     WHERE     qll.list_line_id = qpa.list_line_id
                           AND qph.list_header_id = qll.list_header_id
                           AND qph.list_header_id = qpt.list_header_id
                           AND qpt.language = USERENV ('LANG')
                           AND qll.list_line_type_code = 'PLL'
                           AND qph.name = xpap.price_list_name
                           AND xpap.status = 'N'
                           AND NVL (UPPER (xpap.record_status), 'UPDATE') =
                               'UPDATE'
                           AND xpap.uom = qll.product_uom_code
                           AND qll.product_attribute_context =
                               xpap.product_context
                           AND qll.product_attribute = xpap.product_attribute
                           AND qll.product_attr_value =
                               xxd_qp_add_price_list_pkg.Get_Product_Value (
                                   'QP_ATTR_DEFNS_PRICING',
                                   xpap.product_context,
                                   xpap.product_attribute,
                                   xpap.product_value)
                           /*  AND TRUNC (SYSDATE) BETWEEN NVL (qll.start_date_active,
                                                              SYSDATE - 1)
                                                     AND NVL (qll.end_date_active,
                                                              SYSDATE + 1)*/
                           --Start - commented the below date conditions on 26Jul2016
                           /*
                           AND NVL(qll.start_date_active,SYSDATE) = NVL(xpap.valid_from_date,SYSDATE)
                           AND NVL(qll.end_date_active,SYSDATE)   = NVL(xpap.valid_to_date,SYSDATE);
                           */
                           --End - commented the below date conditions on 26Jul2016
                           --Added the season condition on 26jul2016 --START
                           AND qll.attribute2 = xpap.season--Added the season condition on 26jul2016 --END
                                                           )
             WHERE 1 = 1 AND my_rank = 1; --Top Row(Max List Line Id row is returned)

        --Replaced this cursor query with the above one on 26Jul2016 --START
        /*SELECT qph.list_header_id,
               qll.list_line_id,
               xpap.valid_from_date,
               NVL(xpap.valid_to_date,SYSDATE) valid_to_date,
               xpap.price,
               xpap.uom,
               UPPER(xpap.brand) brand,
               UPPER(xpap.season) season,
               xpap.record_status,
               xpap.PRODUCT_CONTEXT,
               xpap.PRODUCT_ATTRIBUTE,
               xpap.price_list_name,
               xpap.product_value product_val,
               qll.product_attr_value product_value
          FROM qp_list_lines_v qll,
               qp_pricing_attributes qpa,
               QP_LIST_HEADERS_all QPH,
               qp_list_headers_tl qpt,
               xxd_qp_add_price_list_tbl xpap
         WHERE     qll.list_line_id                            = qpa.list_line_id
               AND qph.list_header_id                          = qll.list_header_id
               AND qph.list_header_id                          = qpt.list_header_id
               AND qpt.language                                = USERENV ('LANG')
               AND qll.list_line_type_code                     = 'PLL'
               AND qph.name                                    = xpap.price_list_name
               AND xpap.status                                 = 'N'
               AND NVL (UPPER (xpap.record_status), 'UPDATE')  = 'UPDATE'
               AND xpap.uom                                    = qll.product_uom_code
               AND qll.product_attribute_context               = xpap.product_context
               AND qll.product_attribute                       = xpap.product_attribute
               AND qll.product_attr_value = Get_Product_Value ('QP_ATTR_DEFNS_PRICING',
                                                                xpap.product_context,
                                                                xpap.product_attribute,
                                                                xpap.product_value)
              -- AND TRUNC (SYSDATE) BETWEEN NVL (qll.start_date_active,
                  --                              SYSDATE - 1)
                    --                   AND NVL (qll.end_date_active,
                      --                          SYSDATE + 1)
               AND NVL(qll.start_date_active,SYSDATE) = NVL(xpap.valid_from_date,SYSDATE)
               AND NVL(qll.end_date_active,SYSDATE)   = NVL(xpap.valid_to_date,SYSDATE);
          */
        --Replaced this cursor query with the above one on 26Jul2016 --START

        CURSOR cur_price_list_delete IS
            SELECT qph.list_header_id, qll.list_line_id, qll.start_date_active,
                   qll.end_date_active, xpap.valid_from_date, xpap.valid_to_date,
                   xpap.price, xpap.uom, UPPER (xpap.brand) brand,
                   UPPER (xpap.season) season, xpap.record_status, xpap.product_context,
                   xpap.product_attribute, xpap.price_list_name, xpap.product_value product_val,
                   qll.product_attr_value product_value
              FROM qp_list_lines_v qll, qp_pricing_attributes qpa, qp_list_headers_all qph,
                   qp_list_headers_tl qpt, xxd_qp_add_price_list_tbl xpap
             WHERE     qll.list_line_id = qpa.list_line_id
                   AND qph.list_header_id = qll.list_header_id
                   AND qph.list_header_id = qpt.list_header_id
                   AND qpt.language = USERENV ('LANG')
                   AND qll.list_line_type_code = 'PLL'
                   AND qph.name = xpap.price_list_name
                   AND xpap.status = 'N'
                   AND NVL (UPPER (xpap.record_status), 'UPDATE') = 'DELETE'
                   AND xpap.uom = qll.product_uom_code
                   AND qll.product_attribute_context = xpap.product_context
                   AND qll.product_attribute = xpap.product_attribute
                   AND qll.product_attr_value =
                       get_product_value ('QP_ATTR_DEFNS_PRICING', xpap.product_context, xpap.product_attribute
                                          , xpap.product_value)
                   AND TRUNC (SYSDATE) BETWEEN NVL (qll.start_date_active,
                                                    SYSDATE - 1)
                                           AND NVL (qll.end_date_active,
                                                    SYSDATE + 1)
                   AND qll.start_date_active IS NOT NULL;

        CURSOR get_procedence_c (p_item_cat IN VARCHAR2)
        IS
            SELECT qsv.user_precedence
              FROM qp_prc_contexts_v qpc, qp_segments_v qsv
             WHERE     qsv.prc_context_id = qpc.prc_context_id
                   AND prc_context_type = 'PRODUCT'
                   AND prc_context_code = 'ITEM'
                   AND segment_code =
                       DECODE (p_item_cat,
                               'PRICING_ATTRIBUTE1', 'INVENTORY_ITEM_ID',
                               'ITEM_CATEGORY');

        TYPE t_price_list_add_rec IS TABLE OF cur_price_list_add%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_price_list_add_rec         t_price_list_add_rec;

        TYPE t_price_list_update_rec
            IS TABLE OF cur_price_list_update%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_price_list_update_rec      t_price_list_update_rec;

        TYPE t_price_list_delete_rec
            IS TABLE OF cur_price_list_delete%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_price_list_delete_rec      t_price_list_delete_rec;

        TYPE t_error_rpt_rec IS TABLE OF cur_error_rpt%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_error_rpt_rec              t_error_rpt_rec;

        l_cur_line_det               cur_line_det%ROWTYPE;
        ln_precedence                NUMBER;
    -- End Changes by BT Technology Team on 27-Oct-014
    BEGIN
        --Purge Logic added on 26Jul2016 --START
        --Archiving the data to archive table
        BEGIN
            INSERT INTO xxd_qp_add_price_list_tbl_arc xpapa    --Archive table
                SELECT xpap.*, SYSDATE archive_date
                  FROM xxd_qp_add_price_list_tbl xpap
                 WHERE     1 = 1
                       --AND xpap.status <> 'N'
                       AND TRUNC (xpap.update_date) <=
                           TRUNC (SYSDATE - p_purge_days);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'exception while archiving the data to archive table: '
                    || SQLERRM);
        END;

        --Deleting the data from main staging table
        BEGIN
            DELETE FROM
                xxd_qp_add_price_list_tbl xpap
                  WHERE     1 = 1
                        --AND xpap.status <> 'N'
                        AND TRUNC (xpap.update_date) <=
                            TRUNC (SYSDATE - p_purge_days);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'exception while purging the data from staging table : '
                    || SQLERRM);
        END;

        COMMIT;

        --Purge Logic added on 26Jul2016--END

        mo_global.set_policy_context (
            'S',
            NVL (mo_global.get_current_org_id, mo_utils.get_default_org_id));

        OPEN cur_price_list_add;

        FETCH cur_price_list_add BULK COLLECT INTO l_price_list_add_rec;

        CLOSE cur_price_list_add;

        FOR l_add IN 1 .. l_price_list_add_rec.COUNT
        LOOP
            l_return_status1                   := NULL;
            l_msg_data1                        := NULL;
            l_cur_line_det                     := NULL;

            IF l_price_list_add_rec (l_add).product_value IS NULL
            THEN
                print_log (
                       'Not able to find item/category for '
                    || l_price_list_add_rec (l_add).product_val);
                UPDATE_STATUS (
                    p_status   => 'E',
                    p_error_message   =>
                           'Not able to find item/category for '
                        || l_price_list_add_rec (l_add).product_val,
                    p_price_list_name   =>
                        l_price_list_add_rec (l_add).price_list_name,
                    p_product_context   =>
                        l_price_list_add_rec (l_add).product_context,
                    p_product_attribute   =>
                        l_price_list_add_rec (l_add).product_attribute,
                    p_product_value   =>
                        l_price_list_add_rec (l_add).product_val);
            ELSE
                OPEN get_procedence_c (
                    l_price_list_add_rec (l_add).product_attribute);

                FETCH get_procedence_c INTO ln_precedence;

                CLOSE get_procedence_c;

                OPEN cur_line_det (
                    l_price_list_add_rec (l_add).list_header_id,
                    l_price_list_add_rec (l_add).product_context,
                    l_price_list_add_rec (l_add).product_attribute,
                    l_price_list_add_rec (l_add).product_value-- Code change on 27-Jul-2016
                                                              ,
                    l_price_list_add_rec (l_add).uom);

                -- End of code change on 27-Jul-2016
                FETCH cur_line_det INTO l_cur_line_det;

                CLOSE cur_line_det;

                IF l_cur_line_det.list_line_id IS NULL
                THEN
                    IF l_price_list_add_rec (l_add).list_header_id
                           IS NOT NULL
                    THEN
                        l_price_list_rec1.list_header_id                 := NULL;
                        l_price_list_rec1.list_type_code                 := NULL;
                        l_price_list_line_tbl1.delete;
                        l_pricing_attr_tbl1.delete;

                        s                                                := 1;
                        l_price_list_rec1.list_header_id                 :=
                            l_price_list_add_rec (l_add).list_header_id;
                        l_price_list_rec1.list_type_code                 := 'PRL';
                        l_price_list_rec1.operation                      :=
                            qp_globals.g_opr_update;
                        l_price_list_line_tbl1 (s).list_header_id        :=
                            l_price_list_add_rec (l_add).list_header_id;
                        l_price_list_line_tbl1 (s).list_line_id          :=
                            qp_list_lines_s.NEXTVAL;
                        l_price_list_line_tbl1 (s).list_line_type_code   :=
                            'PLL';
                        l_price_list_line_tbl1 (s).operation             :=
                            qp_globals.g_opr_create;
                        l_price_list_line_tbl1 (s).operand               :=
                            l_price_list_add_rec (l_add).price;
                        l_price_list_line_tbl1 (s).product_precedence    :=
                            ln_precedence;
                        l_price_list_line_tbl1 (s).attribute1            :=
                            l_price_list_add_rec (l_add).brand;
                        l_price_list_line_tbl1 (s).attribute2            :=
                            l_price_list_add_rec (l_add).season;
                        l_price_list_line_tbl1 (s).arithmetic_operator   :=
                            'UNIT_PRICE';
                        l_price_list_line_tbl1 (s).start_date_active     :=
                            NULL;
                        l_price_list_line_tbl1 (s).end_date_active       :=
                            NULL;
                        t                                                := 1;

                        SELECT apps.qp_pricing_attr_group_no_s.NEXTVAL
                          INTO attr_group_no
                          FROM DUAL;


                        l_pricing_attr_tbl1 (t).list_line_id             :=
                            l_price_list_line_tbl1 (s).list_line_id;
                        l_pricing_attr_tbl1 (t).product_attribute_context   :=
                            l_price_list_add_rec (l_add).product_context; --'ITEM';
                        l_pricing_attr_tbl1 (t).product_attribute        :=
                            l_price_list_add_rec (l_add).product_attribute; -- 'PRICING_ATTRIBUTE1';
                        l_pricing_attr_tbl1 (t).product_attribute_datatype   :=
                            'C';
                        l_pricing_attr_tbl1 (t).product_attr_value       :=
                            l_price_list_add_rec (l_add).product_value;
                        l_pricing_attr_tbl1 (t).product_uom_code         :=
                            l_price_list_add_rec (l_add).uom;
                        l_pricing_attr_tbl1 (t).excluder_flag            :=
                            'N';
                        l_pricing_attr_tbl1 (t).attribute_grouping_no    :=
                            attr_group_no;
                        l_pricing_attr_tbl1 (t).operation                :=
                            qp_globals.g_opr_create;

                        IF l_price_list_add_rec (l_add).product_value
                               IS NOT NULL
                        THEN
                            BEGIN
                                insert_price_list (
                                    p_price_list_rec     => l_price_list_rec1,
                                    p_price_list_line_tbl   =>
                                        l_price_list_line_tbl1,
                                    p_pricing_attr_tbl   =>
                                        l_pricing_attr_tbl1,
                                    x_return_status      => l_return_status1,
                                    x_error_message      => l_msg_data1);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    print_log (
                                        l_return_status1 || '  ' || SQLERRM);
                            END;
                        ELSE
                            print_log (
                                   'Not able to find item/category'
                                || '  '
                                || SQLERRM);
                            UPDATE_STATUS (
                                p_status   => 'E',
                                p_error_message   =>
                                    'Not able to find item/category',
                                p_price_list_name   =>
                                    l_price_list_add_rec (l_add).price_list_name,
                                p_product_context   =>
                                    l_price_list_add_rec (l_add).product_context,
                                p_product_attribute   =>
                                    l_price_list_add_rec (l_add).product_attribute,
                                p_product_value   =>
                                    l_price_list_add_rec (l_add).product_val);
                        END IF;


                        IF ((l_return_status1 <> apps.fnd_api.g_ret_sts_success) OR (l_price_list_add_rec (l_add).product_value IS NULL))
                        THEN
                            print_log ('Error is ' || l_msg_data1);
                            UPDATE_STATUS (
                                p_status   => 'E',
                                p_error_message   =>
                                    SUBSTR (l_msg_data1, 1, 2500),
                                p_price_list_name   =>
                                    l_price_list_add_rec (l_add).price_list_name,
                                p_product_context   =>
                                    l_price_list_add_rec (l_add).product_context,
                                p_product_attribute   =>
                                    l_price_list_add_rec (l_add).product_attribute,
                                p_product_value   =>
                                    l_price_list_add_rec (l_add).product_val);
                        ELSE
                            UPDATE_STATUS (
                                p_status          => 'S',
                                p_error_message   => NULL,
                                p_price_list_name   =>
                                    l_price_list_add_rec (l_add).price_list_name,
                                p_product_context   =>
                                    l_price_list_add_rec (l_add).product_context,
                                p_product_attribute   =>
                                    l_price_list_add_rec (l_add).product_attribute,
                                p_product_value   =>
                                    l_price_list_add_rec (l_add).product_val);
                        END IF;
                    END IF;
                ELSE
                    IF l_price_list_add_rec (l_add).list_header_id
                           IS NOT NULL
                    THEN
                        k                                  := 1;

                        l_price_list_rec1.list_header_id   :=
                            l_price_list_add_rec (l_add).list_header_id;
                        l_price_list_rec1.list_type_code   := 'PRL';
                        l_price_list_rec1.operation        :=
                            qp_globals.g_opr_update;
                        l_price_list_line_tbl1 (k).list_header_id   :=
                            l_price_list_add_rec (l_add).list_header_id;
                        l_price_list_line_tbl1 (k).list_line_id   :=
                            l_cur_line_det.list_line_id;
                        l_price_list_line_tbl1 (k).operation   :=
                            qp_globals.g_opr_update;
                        l_price_list_line_tbl1 (k).end_date_active   :=
                            l_price_list_add_rec (l_add).valid_from_date - 1;
                        -- Change made on 27-Jul-2016
                        l_pricing_attr_tbl1 (t).product_uom_code   :=
                            l_price_list_add_rec (l_add).uom;

                        -- End of Change made on 27-Jul-2016

                        BEGIN
                            insert_price_list (
                                p_price_list_rec     => l_price_list_rec1,
                                p_price_list_line_tbl   =>
                                    l_price_list_line_tbl1,
                                p_pricing_attr_tbl   => l_pricing_attr_tbl1,
                                x_return_status      => l_return_status1,
                                x_error_message      => l_msg_data1);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                print_log (
                                    l_return_status1 || '  ' || SQLERRM);
                        END;

                        COMMIT;

                        IF l_return_status1 <> apps.fnd_api.g_ret_sts_success
                        THEN
                            print_log ('Error is ' || l_msg_data1);
                            UPDATE_STATUS (
                                p_status   => 'E',
                                p_error_message   =>
                                    SUBSTR (l_msg_data1, 1, 1000),
                                p_price_list_name   =>
                                    l_price_list_add_rec (l_add).price_list_name,
                                p_product_context   =>
                                    l_price_list_add_rec (l_add).product_context,
                                p_product_attribute   =>
                                    l_price_list_add_rec (l_add).product_attribute,
                                p_product_value   =>
                                    l_price_list_add_rec (l_add).product_val);
                        ELSE
                            l_price_list_rec1.list_header_id   := NULL;
                            l_price_list_rec1.list_type_code   := NULL;
                            l_price_list_line_tbl1.delete;
                            l_pricing_attr_tbl1.delete;

                            s                                  := 1;
                            l_price_list_rec1.list_header_id   :=
                                l_price_list_add_rec (l_add).list_header_id;
                            l_price_list_rec1.list_type_code   := 'PRL';
                            l_price_list_rec1.operation        :=
                                qp_globals.g_opr_update;
                            l_price_list_line_tbl1 (s).list_header_id   :=
                                l_price_list_add_rec (l_add).list_header_id;
                            l_price_list_line_tbl1 (s).list_line_id   :=
                                qp_list_lines_s.NEXTVAL;
                            l_price_list_line_tbl1 (s).list_line_type_code   :=
                                'PLL';
                            l_price_list_line_tbl1 (s).operation   :=
                                qp_globals.g_opr_create;
                            l_price_list_line_tbl1 (s).product_precedence   :=
                                ln_precedence;
                            l_price_list_line_tbl1 (s).operand   :=
                                l_price_list_add_rec (l_add).price;
                            l_price_list_line_tbl1 (s).attribute1   :=
                                l_price_list_add_rec (l_add).brand;
                            l_price_list_line_tbl1 (s).attribute2   :=
                                l_price_list_add_rec (l_add).season;
                            l_price_list_line_tbl1 (s).arithmetic_operator   :=
                                'UNIT_PRICE';
                            l_price_list_line_tbl1 (s).start_date_active   :=
                                l_price_list_add_rec (l_add).valid_from_date;
                            l_price_list_line_tbl1 (s).end_date_active   :=
                                NULL;
                            t                                  :=
                                1;

                            SELECT apps.qp_pricing_attr_group_no_s.NEXTVAL
                              INTO attr_group_no
                              FROM DUAL;


                            l_pricing_attr_tbl1 (t).list_line_id   :=
                                l_price_list_line_tbl1 (s).list_line_id;
                            l_pricing_attr_tbl1 (t).product_attribute_context   :=
                                l_price_list_add_rec (l_add).product_context; --'ITEM';
                            l_pricing_attr_tbl1 (t).product_attribute   :=
                                l_price_list_add_rec (l_add).product_attribute; -- 'PRICING_ATTRIBUTE1';
                            l_pricing_attr_tbl1 (t).product_attribute_datatype   :=
                                l_cur_line_det.product_attribute_datatype;
                            l_pricing_attr_tbl1 (t).product_attr_value   :=
                                l_price_list_add_rec (l_add).product_value;
                            l_pricing_attr_tbl1 (t).product_uom_code   :=
                                l_price_list_add_rec (l_add).uom;
                            l_pricing_attr_tbl1 (t).excluder_flag   :=
                                'N';
                            l_pricing_attr_tbl1 (t).attribute_grouping_no   :=
                                attr_group_no;
                            l_pricing_attr_tbl1 (t).operation   :=
                                qp_globals.g_opr_create;

                            BEGIN
                                insert_price_list (
                                    p_price_list_rec     => l_price_list_rec1,
                                    p_price_list_line_tbl   =>
                                        l_price_list_line_tbl1,
                                    p_pricing_attr_tbl   =>
                                        l_pricing_attr_tbl1,
                                    x_return_status      => l_return_status1,
                                    x_error_message      => l_msg_data1);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    print_log (
                                        l_return_status1 || '  ' || SQLERRM);
                            END;



                            IF l_return_status1 <>
                               apps.fnd_api.g_ret_sts_success
                            THEN
                                UPDATE_STATUS (
                                    p_status   => 'E',
                                    p_error_message   =>
                                        SUBSTR (l_msg_data1, 1, 1000),
                                    p_price_list_name   =>
                                        l_price_list_add_rec (l_add).price_list_name,
                                    p_product_context   =>
                                        l_price_list_add_rec (l_add).product_context,
                                    p_product_attribute   =>
                                        l_price_list_add_rec (l_add).product_attribute,
                                    p_product_value   =>
                                        l_price_list_add_rec (l_add).product_val);
                            ELSE
                                UPDATE_STATUS (
                                    p_status          => 'S',
                                    p_error_message   => NULL,
                                    p_price_list_name   =>
                                        l_price_list_add_rec (l_add).price_list_name,
                                    p_product_context   =>
                                        l_price_list_add_rec (l_add).product_context,
                                    p_product_attribute   =>
                                        l_price_list_add_rec (l_add).product_attribute,
                                    p_product_value   =>
                                        l_price_list_add_rec (l_add).product_val);
                            END IF;
                        END IF;
                    END IF;
                END IF;
            END IF;

            l_price_list_rec1.list_header_id   := NULL;
            l_price_list_rec1.list_type_code   := NULL;
            l_price_list_line_tbl1.delete;
            l_pricing_attr_tbl1.delete;
        END LOOP;


        -- for updating the price list
        OPEN cur_price_list_update;

        FETCH cur_price_list_update BULK COLLECT INTO l_price_list_update_rec;

        CLOSE cur_price_list_update;

        FOR l_update IN 1 .. l_price_list_update_rec.COUNT
        LOOP
            IF l_price_list_update_rec (l_update).list_header_id IS NOT NULL
            THEN
                k                                  := 1;

                l_price_list_rec1.list_header_id   :=
                    l_price_list_update_rec (l_update).list_header_id;
                l_price_list_rec1.list_type_code   := 'PRL';
                l_price_list_rec1.operation        := qp_globals.g_opr_update;
                l_price_list_line_tbl1 (k).list_header_id   :=
                    l_price_list_update_rec (l_update).list_header_id;
                l_price_list_line_tbl1 (k).list_line_id   :=
                    l_price_list_update_rec (l_update).list_line_id;
                l_price_list_line_tbl1 (k).operation   :=
                    qp_globals.g_opr_update;
                l_price_list_line_tbl1 (k).operand   :=
                    l_price_list_update_rec (l_update).price;

                BEGIN
                    insert_price_list (
                        p_price_list_rec        => l_price_list_rec1,
                        p_price_list_line_tbl   => l_price_list_line_tbl1,
                        p_pricing_attr_tbl      => l_pricing_attr_tbl1,
                        x_return_status         => l_return_status1,
                        x_error_message         => l_msg_data1);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        print_log (l_return_status1 || '  ' || SQLERRM);
                END;

                COMMIT;

                IF l_return_status1 <> apps.fnd_api.g_ret_sts_success
                THEN
                    UPDATE_STATUS (
                        p_status          => 'E',
                        p_error_message   => SUBSTR (l_msg_data1, 1, 1000),
                        p_price_list_name   =>
                            l_price_list_update_rec (l_update).price_list_name,
                        p_product_context   =>
                            l_price_list_update_rec (l_update).product_context,
                        p_product_attribute   =>
                            l_price_list_update_rec (l_update).product_attribute,
                        p_product_value   =>
                            l_price_list_update_rec (l_update).product_val);
                ELSE
                    UPDATE_STATUS (
                        p_status          => 'S',
                        p_error_message   => NULL,
                        p_price_list_name   =>
                            l_price_list_update_rec (l_update).price_list_name,
                        p_product_context   =>
                            l_price_list_update_rec (l_update).product_context,
                        p_product_attribute   =>
                            l_price_list_update_rec (l_update).product_attribute,
                        p_product_value   =>
                            l_price_list_update_rec (l_update).product_val);
                END IF;
            END IF;

            --l_price_list_rec1(k).delete;


            l_price_list_rec1.list_header_id   := NULL;
            l_price_list_rec1.list_type_code   := NULL;
            l_price_list_line_tbl1.delete;
            l_pricing_attr_tbl1.delete;
        END LOOP;

        OPEN cur_price_list_delete;

        FETCH cur_price_list_delete BULK COLLECT INTO l_price_list_delete_rec;

        CLOSE cur_price_list_delete;

        FOR l_delete IN 1 .. l_price_list_delete_rec.COUNT
        LOOP
            IF l_price_list_delete_rec (l_delete).list_header_id IS NOT NULL
            THEN
                k   := 1;

                IF l_price_list_delete_rec (l_delete).end_date_active IS NULL
                THEN
                    l_price_list_rec1.list_header_id             :=
                        l_price_list_delete_rec (l_delete).list_header_id;
                    l_price_list_rec1.list_type_code             := 'PRL';
                    l_price_list_rec1.operation                  :=
                        qp_globals.g_opr_update;
                    l_price_list_line_tbl1 (k).list_header_id    :=
                        l_price_list_delete_rec (l_delete).list_header_id;
                    l_price_list_line_tbl1 (k).list_line_id      :=
                        l_price_list_delete_rec (l_delete).list_line_id;
                    l_price_list_line_tbl1 (k).operation         :=
                        qp_globals.g_opr_delete;
                    l_price_list_line_tbl1 (k).end_date_active   := NULL;

                    BEGIN
                        insert_price_list (
                            p_price_list_rec        => l_price_list_rec1,
                            p_price_list_line_tbl   => l_price_list_line_tbl1,
                            p_pricing_attr_tbl      => l_pricing_attr_tbl1,
                            x_return_status         => l_return_status1,
                            x_error_message         => l_msg_data1);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            print_log (l_return_status1 || '  ' || SQLERRM);
                    END;

                    COMMIT;

                    IF l_return_status1 <> apps.fnd_api.g_ret_sts_success
                    THEN
                        UPDATE_STATUS (
                            p_status          => 'E',
                            p_error_message   => SUBSTR (l_msg_data1, 1, 2500),
                            p_price_list_name   =>
                                l_price_list_delete_rec (l_delete).price_list_name,
                            p_product_context   =>
                                l_price_list_delete_rec (l_delete).product_context,
                            p_product_attribute   =>
                                l_price_list_delete_rec (l_delete).product_attribute,
                            p_product_value   =>
                                l_price_list_delete_rec (l_delete).product_val);
                    ELSE
                        UPDATE_STATUS (
                            p_status          => 'S',
                            p_error_message   => NULL,
                            p_price_list_name   =>
                                l_price_list_delete_rec (l_delete).price_list_name,
                            p_product_context   =>
                                l_price_list_delete_rec (l_delete).product_context,
                            p_product_attribute   =>
                                l_price_list_delete_rec (l_delete).product_attribute,
                            p_product_value   =>
                                l_price_list_delete_rec (l_delete).product_val);
                    END IF;
                ELSIF l_price_list_delete_rec (l_delete).end_date_active
                          IS NOT NULL
                THEN
                    k                                            := 1;

                    --print_log ('list id' || rec_price_list.list_Line_id);

                    l_price_list_rec1.list_header_id             :=
                        l_price_list_delete_rec (l_delete).list_header_id;
                    l_price_list_rec1.list_type_code             := 'PRL';
                    l_price_list_rec1.operation                  :=
                        qp_globals.g_opr_update;
                    l_price_list_line_tbl1 (k).list_header_id    :=
                        l_price_list_delete_rec (l_delete).list_header_id;
                    l_price_list_line_tbl1 (k).list_line_id      :=
                        l_price_list_delete_rec (l_delete).list_line_id;
                    l_price_list_line_tbl1 (k).operation         :=
                        qp_globals.g_opr_update;
                    l_price_list_line_tbl1 (k).end_date_active   := NULL;

                    BEGIN
                        insert_price_list (
                            p_price_list_rec        => l_price_list_rec1,
                            p_price_list_line_tbl   => l_price_list_line_tbl1,
                            p_pricing_attr_tbl      => l_pricing_attr_tbl1,
                            x_return_status         => l_return_status1,
                            x_error_message         => l_msg_data1);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            print_log (l_return_status1 || '  ' || SQLERRM);
                    END;

                    COMMIT;

                    IF l_return_status1 <> apps.fnd_api.g_ret_sts_success
                    THEN
                        UPDATE_STATUS (
                            p_status          => 'E',
                            p_error_message   => SUBSTR (l_msg_data1, 1, 2500),
                            p_price_list_name   =>
                                l_price_list_delete_rec (l_delete).price_list_name,
                            p_product_context   =>
                                l_price_list_delete_rec (l_delete).product_context,
                            p_product_attribute   =>
                                l_price_list_delete_rec (l_delete).product_attribute,
                            p_product_value   =>
                                l_price_list_delete_rec (l_delete).product_val);
                    ELSE
                        UPDATE_STATUS (
                            p_status          => 'S',
                            p_error_message   => NULL,
                            p_price_list_name   =>
                                l_price_list_delete_rec (l_delete).price_list_name,
                            p_product_context   =>
                                l_price_list_delete_rec (l_delete).product_context,
                            p_product_attribute   =>
                                l_price_list_delete_rec (l_delete).product_attribute,
                            p_product_value   =>
                                l_price_list_delete_rec (l_delete).product_val);
                    END IF;
                END IF;
            END IF;

            --l_price_list_rec1(k).delete;



            l_price_list_rec1.list_header_id   := NULL;
            l_price_list_rec1.list_type_code   := NULL;
            l_price_list_line_tbl1.delete;
            l_pricing_attr_tbl1.delete;
        END LOOP;

        COMMIT;

        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'Error Report for the data ran today');
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            '*********************************************************************************');
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
               RPAD ('Price List Name', 40, ' ')
            || RPAD ('Product Context', 20, ' ')
            || RPAD ('Product Value', 30, ' ')
            || RPAD ('UOM', 10, ' ')
            || 'Error Message');

        OPEN cur_error_rpt;

        FETCH cur_error_rpt BULK COLLECT INTO l_error_rpt_rec;

        CLOSE cur_error_rpt;

        FOR i IN 1 .. l_error_rpt_rec.COUNT
        LOOP
            IF l_error_rpt_rec.COUNT = 0
            THEN
                FND_FILE.PUT_LINE (FND_FILE.LOG,
                                   'No Errors for the data ran today');
            ELSE
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       RPAD (l_error_rpt_rec (i).price_list_name, 40, ' ')
                    || RPAD (l_error_rpt_rec (i).product_attribute, 20, ' ')
                    || RPAD (l_error_rpt_rec (i).product_value, 30, ' ')
                    || RPAD (l_error_rpt_rec (i).uom, 10, ' ')
                    || l_error_rpt_rec (i).error_message);
            END IF;
        END LOOP;



        -- End Changes by BT Technology Team on 27-Oct-014

        print_log ('program completed successfully');
    EXCEPTION
        WHEN OTHERS
        THEN
            write_out (
                   'Unexpected Error Encountered : '
                || SQLCODE
                || '-'
                || SQLERRM);

            print_log (
                   'Unexpected Error Encountered : '
                || SQLCODE
                || '-'
                || SQLERRM);     -- Added by BT Technology Team on 27-Oct-2014
            errbuf    := 'Request completed with warning';
            retcode   := '1';
            g_temp    := fnd_concurrent.set_completion_status ('WARNING', '');
            ROLLBACK;
    END xxdoqp_populate_pricelist;
END XXD_QP_ADD_PRICE_LIST_PKG;
/
