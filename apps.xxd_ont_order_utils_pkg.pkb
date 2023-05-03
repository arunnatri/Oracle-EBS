--
-- XXD_ONT_ORDER_UTILS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:27 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_ORDER_UTILS_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_ORDER_UTILS_PKG
    * Design       : This package will manage the bulk calloff process
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 05-Mar-2020  1.0        Deckers                 Initial Version
    -- 03-Aug-2021  1.1        Viswanathan Pandian     Updated for CCR0009505
    -- 16-Aug-2021  1.2        Viswanathan Pandian     Updated for CCR0009529 to replace the DB link name
    -- 18-Aug-2021  1.3        Viswanathan Pandian     Updated for CCR0009550
    -- 31-Aug-2021  1.4        Viswanathan Pandian     Updated for CCR0009567
    -- 21-Oct-2021  1.5        Viswanathan Pandian     Updated for CCR0009669
    -- 08-Nov-2021  1.6        Viswanathan Pandian     Updated for CCR0009692 and added all exception block
    --                                                 messages as primary debug level 1
    -- 17-JAN-2023  1.7        Srinath Siricilla       Updated for CCR0010401
    -- 27-JAN-2023  1.8        Srinath Siricilla       CCR0010423 (PDCTOM-126)
    -- 03-Mar-2023  1.9        Gaurav Joshi            CCR00010492( PDCTOM 512 and 630)
    ******************************************************************************************/

    PROCEDURE msg (pc_msg         VARCHAR2,
                   pn_log_level   NUMBER:= 9.99e125,
                   pc_origin      VARCHAR2:= 'Local Delegated Debug')
    IS
    BEGIN
        xxd_debug_tools_pkg.msg (pc_msg         => pc_msg,
                                 pn_log_level   => pn_log_level,
                                 pc_origin      => pc_origin);
    END msg;

    FUNCTION lock_order_line (pn_line_id NUMBER)
        RETURN oe_order_lines_all%ROWTYPE
    IS
        lr_order_line   oe_order_lines_all%ROWTYPE;
    BEGIN
        SELECT *
          INTO lr_order_line
          FROM oe_order_lines_all
         WHERE line_id = pn_line_id;

        RETURN lr_order_line;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END lock_order_line;

    PROCEDURE create_oe_reason (pn_line_id IN NUMBER, pc_reason_type IN VARCHAR2, pc_reason_code IN VARCHAR2
                                , pc_comment IN VARCHAR2, xn_reason_id OUT NUMBER, xc_ret_stat OUT VARCHAR2)
    AS
        ln_reason_validate   NUMBER;
        lc_ret_stat          VARCHAR2 (1);
        lr_reason            oe_reasons%ROWTYPE;
    BEGIN
        xc_ret_stat                := g_ret_sts_success;

        SELECT COUNT (*)
          INTO ln_reason_validate
          FROM fnd_lookup_values
         WHERE     lookup_type = pc_reason_type
               AND lookup_code = pc_reason_code
               AND language = 'US';

        IF ln_reason_validate = 0
        THEN
            msg (
                   'Unable to locate lookup value for supplied reason type ('
                || pc_reason_type
                || ') and code ('
                || pc_reason_code
                || ')',
                1);
            RAISE NO_DATA_FOUND;
        END IF;

        SELECT oe_reasons_s.NEXTVAL INTO lr_reason.reason_id FROM DUAL;

        SELECT header_id, line_id, line_id
          INTO lr_reason.header_id, lr_reason.line_id, lr_reason.entity_id
          FROM oe_order_lines_all
         WHERE line_id = pn_line_id;

        lr_reason.entity_code      := 'LINE';
        lr_reason.version_number   := 0;
        lr_reason.reason_type      := pc_reason_type;
        lr_reason.reason_code      := pc_reason_code;

        IF 1 = 1
        THEN                                                   -- code folding
            lr_reason.comments            := pc_comment;
            lr_reason.creation_date       := SYSDATE;
            lr_reason.created_by          := NVL (fnd_global.user_id, -1);
            lr_reason.last_updated_by     := NVL (fnd_global.user_id, -1);
            lr_reason.last_update_date    := SYSDATE;
            lr_reason.last_update_login   := NULL;
            lr_reason.context             := NULL;
            lr_reason.attribute1          := NULL;
            lr_reason.attribute2          := NULL;
            lr_reason.attribute3          := NULL;
            lr_reason.attribute4          := NULL;
            lr_reason.attribute5          := NULL;
            lr_reason.attribute6          := NULL;
            lr_reason.attribute7          := NULL;
            lr_reason.attribute8          := NULL;
            lr_reason.attribute9          := NULL;
            lr_reason.attribute10         := NULL;
            lr_reason.attribute11         := NULL;
            lr_reason.attribute12         := NULL;
            lr_reason.attribute13         := NULL;
            lr_reason.attribute14         := NULL;
            lr_reason.attribute15         := NULL;
            lr_reason.attribute16         := NULL;
            lr_reason.attribute17         := NULL;
            lr_reason.attribute18         := NULL;
            lr_reason.attribute19         := NULL;
            lr_reason.attribute20         := NULL;
        END IF;

        INSERT INTO oe_reasons
             VALUES lr_reason;

        xn_reason_id               := lr_reason.reason_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('OTHER Exception in create_oe_reason:' || SQLERRM, 1);
            xc_ret_stat   := g_ret_sts_error;
    END create_oe_reason;

    PROCEDURE create_order_line_history (
        pr_oe_order_lines    IN     oe_order_lines_all%ROWTYPE,
        pn_cancel_quantity   IN     NUMBER,
        pn_reason_id         IN     NUMBER,
        pc_hist_type_code    IN     VARCHAR2,
        xc_ret_stat             OUT VARCHAR2)
    IS
        lr_oe_order_lines_history   oe_order_lines_history%ROWTYPE;
    BEGIN
        xc_ret_stat   := g_ret_sts_success;

        IF 1 = 1
        THEN                                                   -- code folding
            /*
            select case when oola.column_name is null then '--  ' else '  ' end || 'lr_oe_order_lines_history.' || hist.column_name || ' := pr_oe_order_lines.'||oola.column_name||';' it
              from (select column_id, column_name from all_tab_columns where owner = 'ONT' and table_name = 'OE_ORDER_LINES_HISTORY') hist
                 , (select column_name from all_tab_columns where owner = 'ONT' and table_name = 'OE_ORDER_LINES_ALL') oola
              where oola.column_name (+) = hist.column_name
              order by hist.column_id
            */
            lr_oe_order_lines_history.line_id                          := pr_oe_order_lines.line_id;
            lr_oe_order_lines_history.org_id                           := pr_oe_order_lines.org_id;
            lr_oe_order_lines_history.header_id                        :=
                pr_oe_order_lines.header_id;
            lr_oe_order_lines_history.line_type_id                     :=
                pr_oe_order_lines.line_type_id;
            lr_oe_order_lines_history.line_number                      :=
                pr_oe_order_lines.line_number;
            lr_oe_order_lines_history.request_date                     :=
                pr_oe_order_lines.request_date;
            lr_oe_order_lines_history.promise_date                     :=
                pr_oe_order_lines.promise_date;
            lr_oe_order_lines_history.schedule_ship_date               :=
                pr_oe_order_lines.schedule_ship_date;
            lr_oe_order_lines_history.order_quantity_uom               :=
                pr_oe_order_lines.order_quantity_uom;
            lr_oe_order_lines_history.pricing_quantity                 :=
                pr_oe_order_lines.pricing_quantity;
            lr_oe_order_lines_history.pricing_quantity_uom             :=
                pr_oe_order_lines.pricing_quantity_uom;
            lr_oe_order_lines_history.cancelled_quantity               :=
                pr_oe_order_lines.cancelled_quantity;
            lr_oe_order_lines_history.shipped_quantity                 :=
                pr_oe_order_lines.shipped_quantity;
            lr_oe_order_lines_history.ordered_quantity                 :=
                pr_oe_order_lines.ordered_quantity;
            lr_oe_order_lines_history.fulfilled_quantity               :=
                pr_oe_order_lines.fulfilled_quantity;
            lr_oe_order_lines_history.shipping_quantity                :=
                pr_oe_order_lines.shipping_quantity;
            lr_oe_order_lines_history.shipping_quantity_uom            :=
                pr_oe_order_lines.shipping_quantity_uom;
            lr_oe_order_lines_history.delivery_lead_time               :=
                pr_oe_order_lines.delivery_lead_time;
            lr_oe_order_lines_history.tax_exempt_flag                  :=
                pr_oe_order_lines.tax_exempt_flag;
            lr_oe_order_lines_history.tax_exempt_number                :=
                pr_oe_order_lines.tax_exempt_number;
            lr_oe_order_lines_history.tax_exempt_reason_code           :=
                pr_oe_order_lines.tax_exempt_reason_code;
            lr_oe_order_lines_history.ship_from_org_id                 :=
                pr_oe_order_lines.ship_from_org_id;
            lr_oe_order_lines_history.ship_to_org_id                   :=
                pr_oe_order_lines.ship_to_org_id;
            lr_oe_order_lines_history.invoice_to_org_id                :=
                pr_oe_order_lines.invoice_to_org_id;
            lr_oe_order_lines_history.deliver_to_org_id                :=
                pr_oe_order_lines.deliver_to_org_id;
            lr_oe_order_lines_history.ship_to_contact_id               :=
                pr_oe_order_lines.ship_to_contact_id;
            lr_oe_order_lines_history.deliver_to_contact_id            :=
                pr_oe_order_lines.deliver_to_contact_id;
            lr_oe_order_lines_history.invoice_to_contact_id            :=
                pr_oe_order_lines.invoice_to_contact_id;
            lr_oe_order_lines_history.sold_from_org_id                 :=
                pr_oe_order_lines.sold_from_org_id;
            lr_oe_order_lines_history.sold_to_org_id                   :=
                pr_oe_order_lines.sold_to_org_id;
            lr_oe_order_lines_history.cust_po_number                   :=
                pr_oe_order_lines.cust_po_number;
            lr_oe_order_lines_history.ship_tolerance_above             :=
                pr_oe_order_lines.ship_tolerance_above;
            lr_oe_order_lines_history.ship_tolerance_below             :=
                pr_oe_order_lines.ship_tolerance_below;
            lr_oe_order_lines_history.demand_bucket_type_code          :=
                pr_oe_order_lines.demand_bucket_type_code;
            lr_oe_order_lines_history.veh_cus_item_cum_key_id          :=
                pr_oe_order_lines.veh_cus_item_cum_key_id;
            lr_oe_order_lines_history.rla_schedule_type_code           :=
                pr_oe_order_lines.rla_schedule_type_code;
            lr_oe_order_lines_history.customer_dock_code               :=
                pr_oe_order_lines.customer_dock_code;
            lr_oe_order_lines_history.customer_job                     :=
                pr_oe_order_lines.customer_job;
            lr_oe_order_lines_history.customer_production_line         :=
                pr_oe_order_lines.customer_production_line;
            lr_oe_order_lines_history.cust_model_serial_number         :=
                pr_oe_order_lines.cust_model_serial_number;
            lr_oe_order_lines_history.project_id                       :=
                pr_oe_order_lines.project_id;
            lr_oe_order_lines_history.task_id                          :=
                pr_oe_order_lines.task_id;
            lr_oe_order_lines_history.inventory_item_id                :=
                pr_oe_order_lines.inventory_item_id;
            lr_oe_order_lines_history.tax_date                         :=
                pr_oe_order_lines.tax_date;
            lr_oe_order_lines_history.tax_code                         :=
                pr_oe_order_lines.tax_code;
            lr_oe_order_lines_history.tax_rate                         :=
                pr_oe_order_lines.tax_rate;
            lr_oe_order_lines_history.demand_class_code                :=
                pr_oe_order_lines.demand_class_code;
            lr_oe_order_lines_history.price_list_id                    :=
                pr_oe_order_lines.price_list_id;
            lr_oe_order_lines_history.pricing_date                     :=
                pr_oe_order_lines.pricing_date;
            lr_oe_order_lines_history.shipment_number                  :=
                pr_oe_order_lines.shipment_number;
            lr_oe_order_lines_history.agreement_id                     :=
                pr_oe_order_lines.agreement_id;
            lr_oe_order_lines_history.shipment_priority_code           :=
                pr_oe_order_lines.shipment_priority_code;
            lr_oe_order_lines_history.shipping_method_code             :=
                pr_oe_order_lines.shipping_method_code;
            lr_oe_order_lines_history.freight_carrier_code             :=
                pr_oe_order_lines.freight_carrier_code;
            lr_oe_order_lines_history.freight_terms_code               :=
                pr_oe_order_lines.freight_terms_code;
            lr_oe_order_lines_history.fob_point_code                   :=
                pr_oe_order_lines.fob_point_code;
            lr_oe_order_lines_history.tax_point_code                   :=
                pr_oe_order_lines.tax_point_code;
            lr_oe_order_lines_history.payment_term_id                  :=
                pr_oe_order_lines.payment_term_id;
            lr_oe_order_lines_history.invoicing_rule_id                :=
                pr_oe_order_lines.invoicing_rule_id;
            lr_oe_order_lines_history.accounting_rule_id               :=
                pr_oe_order_lines.accounting_rule_id;
            lr_oe_order_lines_history.source_document_type_id          :=
                pr_oe_order_lines.source_document_type_id;
            lr_oe_order_lines_history.orig_sys_document_ref            :=
                pr_oe_order_lines.orig_sys_document_ref;
            lr_oe_order_lines_history.source_document_id               :=
                pr_oe_order_lines.source_document_id;
            lr_oe_order_lines_history.orig_sys_line_ref                :=
                pr_oe_order_lines.orig_sys_line_ref;
            lr_oe_order_lines_history.source_document_line_id          :=
                pr_oe_order_lines.source_document_line_id;
            lr_oe_order_lines_history.reference_line_id                :=
                pr_oe_order_lines.reference_line_id;
            lr_oe_order_lines_history.reference_type                   :=
                pr_oe_order_lines.reference_type;
            lr_oe_order_lines_history.reference_header_id              :=
                pr_oe_order_lines.reference_header_id;
            lr_oe_order_lines_history.item_revision                    :=
                pr_oe_order_lines.item_revision;
            lr_oe_order_lines_history.unit_selling_price               :=
                pr_oe_order_lines.unit_selling_price;
            lr_oe_order_lines_history.unit_list_price                  :=
                pr_oe_order_lines.unit_list_price;
            lr_oe_order_lines_history.tax_value                        :=
                pr_oe_order_lines.tax_value;
            lr_oe_order_lines_history.context                          :=
                pr_oe_order_lines.context;
            lr_oe_order_lines_history.attribute1                       :=
                pr_oe_order_lines.attribute1;
            lr_oe_order_lines_history.attribute2                       :=
                pr_oe_order_lines.attribute2;
            lr_oe_order_lines_history.attribute3                       :=
                pr_oe_order_lines.attribute3;
            lr_oe_order_lines_history.attribute4                       :=
                pr_oe_order_lines.attribute4;
            lr_oe_order_lines_history.attribute5                       :=
                pr_oe_order_lines.attribute5;
            lr_oe_order_lines_history.attribute6                       :=
                pr_oe_order_lines.attribute6;
            lr_oe_order_lines_history.attribute7                       :=
                pr_oe_order_lines.attribute7;
            lr_oe_order_lines_history.attribute8                       :=
                pr_oe_order_lines.attribute8;
            lr_oe_order_lines_history.attribute9                       :=
                pr_oe_order_lines.attribute9;
            lr_oe_order_lines_history.attribute10                      :=
                pr_oe_order_lines.attribute10;
            lr_oe_order_lines_history.attribute11                      :=
                pr_oe_order_lines.attribute11;
            lr_oe_order_lines_history.attribute12                      :=
                pr_oe_order_lines.attribute12;
            lr_oe_order_lines_history.attribute13                      :=
                pr_oe_order_lines.attribute13;
            lr_oe_order_lines_history.attribute14                      :=
                pr_oe_order_lines.attribute14;
            lr_oe_order_lines_history.attribute15                      :=
                pr_oe_order_lines.attribute15;
            lr_oe_order_lines_history.global_attribute_category        :=
                pr_oe_order_lines.global_attribute_category;
            lr_oe_order_lines_history.global_attribute1                :=
                pr_oe_order_lines.global_attribute1;
            lr_oe_order_lines_history.global_attribute2                :=
                pr_oe_order_lines.global_attribute2;
            lr_oe_order_lines_history.global_attribute3                :=
                pr_oe_order_lines.global_attribute3;
            lr_oe_order_lines_history.global_attribute4                :=
                pr_oe_order_lines.global_attribute4;
            lr_oe_order_lines_history.global_attribute5                :=
                pr_oe_order_lines.global_attribute5;
            lr_oe_order_lines_history.global_attribute6                :=
                pr_oe_order_lines.global_attribute6;
            lr_oe_order_lines_history.global_attribute7                :=
                pr_oe_order_lines.global_attribute7;
            lr_oe_order_lines_history.global_attribute8                :=
                pr_oe_order_lines.global_attribute8;
            lr_oe_order_lines_history.global_attribute9                :=
                pr_oe_order_lines.global_attribute9;
            lr_oe_order_lines_history.global_attribute10               :=
                pr_oe_order_lines.global_attribute10;
            lr_oe_order_lines_history.global_attribute11               :=
                pr_oe_order_lines.global_attribute11;
            lr_oe_order_lines_history.global_attribute12               :=
                pr_oe_order_lines.global_attribute12;
            lr_oe_order_lines_history.global_attribute13               :=
                pr_oe_order_lines.global_attribute13;
            lr_oe_order_lines_history.global_attribute14               :=
                pr_oe_order_lines.global_attribute14;
            lr_oe_order_lines_history.global_attribute15               :=
                pr_oe_order_lines.global_attribute15;
            lr_oe_order_lines_history.global_attribute16               :=
                pr_oe_order_lines.global_attribute16;
            lr_oe_order_lines_history.global_attribute17               :=
                pr_oe_order_lines.global_attribute17;
            lr_oe_order_lines_history.global_attribute18               :=
                pr_oe_order_lines.global_attribute18;
            lr_oe_order_lines_history.global_attribute19               :=
                pr_oe_order_lines.global_attribute19;
            lr_oe_order_lines_history.global_attribute20               :=
                pr_oe_order_lines.global_attribute20;
            lr_oe_order_lines_history.pricing_context                  :=
                pr_oe_order_lines.pricing_context;
            lr_oe_order_lines_history.pricing_attribute1               :=
                pr_oe_order_lines.pricing_attribute1;
            lr_oe_order_lines_history.pricing_attribute2               :=
                pr_oe_order_lines.pricing_attribute2;
            lr_oe_order_lines_history.pricing_attribute3               :=
                pr_oe_order_lines.pricing_attribute3;
            lr_oe_order_lines_history.pricing_attribute4               :=
                pr_oe_order_lines.pricing_attribute4;
            lr_oe_order_lines_history.pricing_attribute5               :=
                pr_oe_order_lines.pricing_attribute5;
            lr_oe_order_lines_history.pricing_attribute6               :=
                pr_oe_order_lines.pricing_attribute6;
            lr_oe_order_lines_history.pricing_attribute7               :=
                pr_oe_order_lines.pricing_attribute7;
            lr_oe_order_lines_history.pricing_attribute8               :=
                pr_oe_order_lines.pricing_attribute8;
            lr_oe_order_lines_history.pricing_attribute9               :=
                pr_oe_order_lines.pricing_attribute9;
            lr_oe_order_lines_history.pricing_attribute10              :=
                pr_oe_order_lines.pricing_attribute10;
            lr_oe_order_lines_history.industry_context                 :=
                pr_oe_order_lines.industry_context;
            lr_oe_order_lines_history.industry_attribute1              :=
                pr_oe_order_lines.industry_attribute1;
            lr_oe_order_lines_history.industry_attribute2              :=
                pr_oe_order_lines.industry_attribute2;
            lr_oe_order_lines_history.industry_attribute3              :=
                pr_oe_order_lines.industry_attribute3;
            lr_oe_order_lines_history.industry_attribute4              :=
                pr_oe_order_lines.industry_attribute4;
            lr_oe_order_lines_history.industry_attribute5              :=
                pr_oe_order_lines.industry_attribute5;
            lr_oe_order_lines_history.industry_attribute6              :=
                pr_oe_order_lines.industry_attribute6;
            lr_oe_order_lines_history.industry_attribute7              :=
                pr_oe_order_lines.industry_attribute7;
            lr_oe_order_lines_history.industry_attribute8              :=
                pr_oe_order_lines.industry_attribute8;
            lr_oe_order_lines_history.industry_attribute9              :=
                pr_oe_order_lines.industry_attribute9;
            lr_oe_order_lines_history.industry_attribute10             :=
                pr_oe_order_lines.industry_attribute10;
            lr_oe_order_lines_history.industry_attribute11             :=
                pr_oe_order_lines.industry_attribute11;
            lr_oe_order_lines_history.industry_attribute13             :=
                pr_oe_order_lines.industry_attribute13;
            lr_oe_order_lines_history.industry_attribute12             :=
                pr_oe_order_lines.industry_attribute12;
            lr_oe_order_lines_history.industry_attribute14             :=
                pr_oe_order_lines.industry_attribute14;
            lr_oe_order_lines_history.industry_attribute15             :=
                pr_oe_order_lines.industry_attribute15;
            lr_oe_order_lines_history.industry_attribute16             :=
                pr_oe_order_lines.industry_attribute16;
            lr_oe_order_lines_history.industry_attribute17             :=
                pr_oe_order_lines.industry_attribute17;
            lr_oe_order_lines_history.industry_attribute18             :=
                pr_oe_order_lines.industry_attribute18;
            lr_oe_order_lines_history.industry_attribute19             :=
                pr_oe_order_lines.industry_attribute19;
            lr_oe_order_lines_history.industry_attribute20             :=
                pr_oe_order_lines.industry_attribute20;
            lr_oe_order_lines_history.industry_attribute21             :=
                pr_oe_order_lines.industry_attribute21;
            lr_oe_order_lines_history.industry_attribute22             :=
                pr_oe_order_lines.industry_attribute22;
            lr_oe_order_lines_history.industry_attribute23             :=
                pr_oe_order_lines.industry_attribute23;
            lr_oe_order_lines_history.industry_attribute24             :=
                pr_oe_order_lines.industry_attribute24;
            lr_oe_order_lines_history.industry_attribute25             :=
                pr_oe_order_lines.industry_attribute25;
            lr_oe_order_lines_history.industry_attribute26             :=
                pr_oe_order_lines.industry_attribute26;
            lr_oe_order_lines_history.industry_attribute27             :=
                pr_oe_order_lines.industry_attribute27;
            lr_oe_order_lines_history.industry_attribute28             :=
                pr_oe_order_lines.industry_attribute28;
            lr_oe_order_lines_history.industry_attribute29             :=
                pr_oe_order_lines.industry_attribute29;
            lr_oe_order_lines_history.industry_attribute30             :=
                pr_oe_order_lines.industry_attribute30;
            lr_oe_order_lines_history.creation_date                    :=
                pr_oe_order_lines.creation_date;
            lr_oe_order_lines_history.created_by                       :=
                pr_oe_order_lines.created_by;
            lr_oe_order_lines_history.last_update_date                 :=
                pr_oe_order_lines.last_update_date;
            lr_oe_order_lines_history.last_updated_by                  :=
                pr_oe_order_lines.last_updated_by;
            lr_oe_order_lines_history.last_update_login                :=
                pr_oe_order_lines.last_update_login;
            lr_oe_order_lines_history.program_application_id           :=
                pr_oe_order_lines.program_application_id;
            lr_oe_order_lines_history.program_id                       :=
                pr_oe_order_lines.program_id;
            lr_oe_order_lines_history.program_update_date              :=
                pr_oe_order_lines.program_update_date;
            lr_oe_order_lines_history.request_id                       :=
                pr_oe_order_lines.request_id;
            lr_oe_order_lines_history.configuration_id                 :=
                pr_oe_order_lines.configuration_id;
            lr_oe_order_lines_history.link_to_line_id                  :=
                pr_oe_order_lines.link_to_line_id;
            lr_oe_order_lines_history.component_sequence_id            :=
                pr_oe_order_lines.component_sequence_id;
            lr_oe_order_lines_history.component_code                   :=
                pr_oe_order_lines.component_code;
            lr_oe_order_lines_history.config_display_sequence          :=
                pr_oe_order_lines.config_display_sequence;
            lr_oe_order_lines_history.sort_order                       :=
                pr_oe_order_lines.sort_order;
            lr_oe_order_lines_history.item_type_code                   :=
                pr_oe_order_lines.item_type_code;
            lr_oe_order_lines_history.option_number                    :=
                pr_oe_order_lines.option_number;
            lr_oe_order_lines_history.option_flag                      :=
                pr_oe_order_lines.option_flag;
            lr_oe_order_lines_history.dep_plan_required_flag           :=
                pr_oe_order_lines.dep_plan_required_flag;
            lr_oe_order_lines_history.visible_demand_flag              :=
                pr_oe_order_lines.visible_demand_flag;
            lr_oe_order_lines_history.line_category_code               :=
                pr_oe_order_lines.line_category_code;
            lr_oe_order_lines_history.actual_shipment_date             :=
                pr_oe_order_lines.actual_shipment_date;
            lr_oe_order_lines_history.customer_trx_line_id             :=
                pr_oe_order_lines.customer_trx_line_id;
            lr_oe_order_lines_history.return_context                   :=
                pr_oe_order_lines.return_context;
            lr_oe_order_lines_history.return_attribute1                :=
                pr_oe_order_lines.return_attribute1;
            lr_oe_order_lines_history.return_attribute2                :=
                pr_oe_order_lines.return_attribute2;
            lr_oe_order_lines_history.return_attribute3                :=
                pr_oe_order_lines.return_attribute3;
            lr_oe_order_lines_history.return_attribute4                :=
                pr_oe_order_lines.return_attribute4;
            lr_oe_order_lines_history.return_attribute5                :=
                pr_oe_order_lines.return_attribute5;
            lr_oe_order_lines_history.return_attribute6                :=
                pr_oe_order_lines.return_attribute6;
            lr_oe_order_lines_history.return_attribute7                :=
                pr_oe_order_lines.return_attribute7;
            lr_oe_order_lines_history.return_attribute8                :=
                pr_oe_order_lines.return_attribute8;
            lr_oe_order_lines_history.return_attribute9                :=
                pr_oe_order_lines.return_attribute9;
            lr_oe_order_lines_history.return_attribute10               :=
                pr_oe_order_lines.return_attribute10;
            lr_oe_order_lines_history.return_attribute11               :=
                pr_oe_order_lines.return_attribute11;
            lr_oe_order_lines_history.return_attribute12               :=
                pr_oe_order_lines.return_attribute12;
            lr_oe_order_lines_history.return_attribute13               :=
                pr_oe_order_lines.return_attribute13;
            lr_oe_order_lines_history.return_attribute14               :=
                pr_oe_order_lines.return_attribute14;
            lr_oe_order_lines_history.return_attribute15               :=
                pr_oe_order_lines.return_attribute15;
            lr_oe_order_lines_history.intmed_ship_to_org_id            :=
                pr_oe_order_lines.intmed_ship_to_org_id;
            lr_oe_order_lines_history.intmed_ship_to_contact_id        :=
                pr_oe_order_lines.intmed_ship_to_contact_id;
            lr_oe_order_lines_history.actual_arrival_date              :=
                pr_oe_order_lines.actual_arrival_date;
            lr_oe_order_lines_history.ato_line_id                      :=
                pr_oe_order_lines.ato_line_id;
            lr_oe_order_lines_history.auto_selected_quantity           :=
                pr_oe_order_lines.auto_selected_quantity;
            lr_oe_order_lines_history.component_number                 :=
                pr_oe_order_lines.component_number;
            lr_oe_order_lines_history.earliest_acceptable_date         :=
                pr_oe_order_lines.earliest_acceptable_date;
            lr_oe_order_lines_history.explosion_date                   :=
                pr_oe_order_lines.explosion_date;
            lr_oe_order_lines_history.latest_acceptable_date           :=
                pr_oe_order_lines.latest_acceptable_date;
            lr_oe_order_lines_history.model_group_number               :=
                pr_oe_order_lines.model_group_number;
            lr_oe_order_lines_history.schedule_arrival_date            :=
                pr_oe_order_lines.schedule_arrival_date;
            lr_oe_order_lines_history.ship_model_complete_flag         :=
                pr_oe_order_lines.ship_model_complete_flag;
            lr_oe_order_lines_history.schedule_status_code             :=
                pr_oe_order_lines.schedule_status_code;
            lr_oe_order_lines_history.source_type_code                 :=
                pr_oe_order_lines.source_type_code;
            lr_oe_order_lines_history.top_model_line_id                :=
                pr_oe_order_lines.top_model_line_id;
            lr_oe_order_lines_history.booked_flag                      :=
                pr_oe_order_lines.booked_flag;
            lr_oe_order_lines_history.cancelled_flag                   :=
                pr_oe_order_lines.cancelled_flag;
            lr_oe_order_lines_history.open_flag                        :=
                pr_oe_order_lines.open_flag;
            lr_oe_order_lines_history.salesrep_id                      :=
                pr_oe_order_lines.salesrep_id;
            lr_oe_order_lines_history.return_reason_code               :=
                pr_oe_order_lines.return_reason_code;
            lr_oe_order_lines_history.hist_type_code                   :=
                pc_hist_type_code;
            lr_oe_order_lines_history.hist_creation_date               := SYSDATE;
            lr_oe_order_lines_history.hist_created_by                  :=
                NVL (fnd_global.user_id, -1);
            lr_oe_order_lines_history.cust_production_seq_num          :=
                pr_oe_order_lines.cust_production_seq_num;
            lr_oe_order_lines_history.authorized_to_ship_flag          :=
                pr_oe_order_lines.authorized_to_ship_flag;
            lr_oe_order_lines_history.split_from_line_id               :=
                pr_oe_order_lines.split_from_line_id;
            lr_oe_order_lines_history.over_ship_reason_code            :=
                pr_oe_order_lines.over_ship_reason_code;
            lr_oe_order_lines_history.over_ship_resolved_flag          :=
                pr_oe_order_lines.over_ship_resolved_flag;
            lr_oe_order_lines_history.item_identifier_type             :=
                pr_oe_order_lines.item_identifier_type;
            lr_oe_order_lines_history.arrival_set_id                   :=
                pr_oe_order_lines.arrival_set_id;
            lr_oe_order_lines_history.ship_set_id                      :=
                pr_oe_order_lines.ship_set_id;
            lr_oe_order_lines_history.commitment_id                    :=
                pr_oe_order_lines.commitment_id;
            lr_oe_order_lines_history.shipping_interfaced_flag         :=
                pr_oe_order_lines.shipping_interfaced_flag;
            lr_oe_order_lines_history.credit_invoice_line_id           :=
                pr_oe_order_lines.credit_invoice_line_id;
            lr_oe_order_lines_history.mfg_component_sequence_id        :=
                pr_oe_order_lines.mfg_component_sequence_id;
            lr_oe_order_lines_history.tp_context                       :=
                pr_oe_order_lines.tp_context;
            lr_oe_order_lines_history.tp_attribute1                    :=
                pr_oe_order_lines.tp_attribute1;
            lr_oe_order_lines_history.tp_attribute2                    :=
                pr_oe_order_lines.tp_attribute2;
            lr_oe_order_lines_history.tp_attribute3                    :=
                pr_oe_order_lines.tp_attribute3;
            lr_oe_order_lines_history.tp_attribute4                    :=
                pr_oe_order_lines.tp_attribute4;
            lr_oe_order_lines_history.tp_attribute5                    :=
                pr_oe_order_lines.tp_attribute5;
            lr_oe_order_lines_history.tp_attribute6                    :=
                pr_oe_order_lines.tp_attribute6;
            lr_oe_order_lines_history.tp_attribute7                    :=
                pr_oe_order_lines.tp_attribute7;
            lr_oe_order_lines_history.tp_attribute8                    :=
                pr_oe_order_lines.tp_attribute8;
            lr_oe_order_lines_history.tp_attribute9                    :=
                pr_oe_order_lines.tp_attribute9;
            lr_oe_order_lines_history.tp_attribute10                   :=
                pr_oe_order_lines.tp_attribute10;
            lr_oe_order_lines_history.tp_attribute11                   :=
                pr_oe_order_lines.tp_attribute11;
            lr_oe_order_lines_history.tp_attribute12                   :=
                pr_oe_order_lines.tp_attribute12;
            lr_oe_order_lines_history.tp_attribute13                   :=
                pr_oe_order_lines.tp_attribute13;
            lr_oe_order_lines_history.tp_attribute14                   :=
                pr_oe_order_lines.tp_attribute14;
            lr_oe_order_lines_history.tp_attribute15                   :=
                pr_oe_order_lines.tp_attribute15;
            lr_oe_order_lines_history.fulfillment_method_code          :=
                pr_oe_order_lines.fulfillment_method_code;
            lr_oe_order_lines_history.service_reference_type_code      :=
                pr_oe_order_lines.service_reference_type_code;
            lr_oe_order_lines_history.service_reference_line_id        :=
                pr_oe_order_lines.service_reference_line_id;
            lr_oe_order_lines_history.service_reference_system_id      :=
                pr_oe_order_lines.service_reference_system_id;
            lr_oe_order_lines_history.invoice_interface_status_code    :=
                pr_oe_order_lines.invoice_interface_status_code;
            lr_oe_order_lines_history.ordered_item                     :=
                pr_oe_order_lines.ordered_item;
            lr_oe_order_lines_history.ordered_item_id                  :=
                pr_oe_order_lines.ordered_item_id;
            lr_oe_order_lines_history.service_number                   :=
                pr_oe_order_lines.service_number;
            lr_oe_order_lines_history.service_duration                 :=
                pr_oe_order_lines.service_duration;
            lr_oe_order_lines_history.service_start_date               :=
                pr_oe_order_lines.service_start_date;
            lr_oe_order_lines_history.re_source_flag                   :=
                pr_oe_order_lines.re_source_flag;
            lr_oe_order_lines_history.flow_status_code                 :=
                pr_oe_order_lines.flow_status_code;
            lr_oe_order_lines_history.service_end_date                 :=
                pr_oe_order_lines.service_end_date;
            lr_oe_order_lines_history.service_coterminate_flag         :=
                pr_oe_order_lines.service_coterminate_flag;
            lr_oe_order_lines_history.shippable_flag                   :=
                pr_oe_order_lines.shippable_flag;
            lr_oe_order_lines_history.order_source_id                  :=
                pr_oe_order_lines.order_source_id;
            lr_oe_order_lines_history.orig_sys_shipment_ref            :=
                pr_oe_order_lines.orig_sys_shipment_ref;
            lr_oe_order_lines_history.change_sequence                  :=
                pr_oe_order_lines.change_sequence;
            lr_oe_order_lines_history.drop_ship_flag                   :=
                pr_oe_order_lines.drop_ship_flag;
            lr_oe_order_lines_history.customer_line_number             :=
                pr_oe_order_lines.customer_line_number;
            lr_oe_order_lines_history.customer_shipment_number         :=
                pr_oe_order_lines.customer_shipment_number;
            lr_oe_order_lines_history.customer_item_net_price          :=
                pr_oe_order_lines.customer_item_net_price;
            lr_oe_order_lines_history.customer_payment_term_id         :=
                pr_oe_order_lines.customer_payment_term_id;
            lr_oe_order_lines_history.first_ack_date                   :=
                pr_oe_order_lines.first_ack_date;
            lr_oe_order_lines_history.first_ack_code                   :=
                pr_oe_order_lines.first_ack_code;
            lr_oe_order_lines_history.last_ack_code                    :=
                pr_oe_order_lines.last_ack_code;
            lr_oe_order_lines_history.last_ack_date                    :=
                pr_oe_order_lines.last_ack_date;
            lr_oe_order_lines_history.planning_priority                :=
                pr_oe_order_lines.planning_priority;
            lr_oe_order_lines_history.service_txn_comments             :=
                pr_oe_order_lines.service_txn_comments;
            lr_oe_order_lines_history.service_period                   :=
                pr_oe_order_lines.service_period;
            lr_oe_order_lines_history.unit_selling_percent             :=
                pr_oe_order_lines.unit_selling_percent;
            lr_oe_order_lines_history.unit_list_percent                :=
                pr_oe_order_lines.unit_list_percent;
            lr_oe_order_lines_history.unit_percent_base_price          :=
                pr_oe_order_lines.unit_percent_base_price;
            lr_oe_order_lines_history.model_remnant_flag               :=
                pr_oe_order_lines.model_remnant_flag;
            lr_oe_order_lines_history.service_txn_reason_code          :=
                pr_oe_order_lines.service_txn_reason_code;
            lr_oe_order_lines_history.calculate_price_flag             :=
                pr_oe_order_lines.calculate_price_flag;
            lr_oe_order_lines_history.end_item_unit_number             :=
                pr_oe_order_lines.end_item_unit_number;
            lr_oe_order_lines_history.fulfilled_flag                   :=
                pr_oe_order_lines.fulfilled_flag;
            lr_oe_order_lines_history.config_header_id                 :=
                pr_oe_order_lines.config_header_id;
            lr_oe_order_lines_history.config_rev_nbr                   :=
                pr_oe_order_lines.config_rev_nbr;
            lr_oe_order_lines_history.shipping_instructions            :=
                pr_oe_order_lines.shipping_instructions;
            lr_oe_order_lines_history.packing_instructions             :=
                pr_oe_order_lines.packing_instructions;
            lr_oe_order_lines_history.invoiced_quantity                :=
                pr_oe_order_lines.invoiced_quantity;
            lr_oe_order_lines_history.reference_customer_trx_line_id   :=
                pr_oe_order_lines.reference_customer_trx_line_id;
            lr_oe_order_lines_history.split_by                         :=
                pr_oe_order_lines.split_by;
            lr_oe_order_lines_history.line_set_id                      :=
                pr_oe_order_lines.line_set_id;
            lr_oe_order_lines_history.revenue_amount                   :=
                pr_oe_order_lines.revenue_amount;
            lr_oe_order_lines_history.fulfillment_date                 :=
                pr_oe_order_lines.fulfillment_date;
            lr_oe_order_lines_history.preferred_grade                  :=
                pr_oe_order_lines.preferred_grade;
            lr_oe_order_lines_history.ordered_quantity2                :=
                pr_oe_order_lines.ordered_quantity2;
            lr_oe_order_lines_history.ordered_quantity_uom2            :=
                pr_oe_order_lines.ordered_quantity_uom2;
            lr_oe_order_lines_history.shipped_quantity2                :=
                pr_oe_order_lines.shipped_quantity2;
            lr_oe_order_lines_history.cancelled_quantity2              :=
                pr_oe_order_lines.cancelled_quantity2;
            lr_oe_order_lines_history.shipping_quantity2               :=
                pr_oe_order_lines.shipping_quantity2;
            lr_oe_order_lines_history.shipping_quantity_uom2           :=
                pr_oe_order_lines.shipping_quantity_uom2;
            lr_oe_order_lines_history.fulfilled_quantity2              :=
                pr_oe_order_lines.fulfilled_quantity2;
            lr_oe_order_lines_history.subinventory                     :=
                pr_oe_order_lines.subinventory;
            lr_oe_order_lines_history.unit_list_price_per_pqty         :=
                pr_oe_order_lines.unit_list_price_per_pqty;
            lr_oe_order_lines_history.unit_selling_price_per_pqty      :=
                pr_oe_order_lines.unit_selling_price_per_pqty;
            lr_oe_order_lines_history.latest_cancelled_quantity        :=
                pn_cancel_quantity;
            lr_oe_order_lines_history.price_request_code               :=
                pr_oe_order_lines.price_request_code;
            lr_oe_order_lines_history.late_demand_penalty_factor       :=
                pr_oe_order_lines.late_demand_penalty_factor;
            lr_oe_order_lines_history.override_atp_date_code           :=
                pr_oe_order_lines.override_atp_date_code;
            lr_oe_order_lines_history.item_substitution_type_code      :=
                pr_oe_order_lines.item_substitution_type_code;
            lr_oe_order_lines_history.original_item_identifier_type    :=
                pr_oe_order_lines.original_item_identifier_type;
            lr_oe_order_lines_history.original_ordered_item            :=
                pr_oe_order_lines.original_ordered_item;
            lr_oe_order_lines_history.original_ordered_item_id         :=
                pr_oe_order_lines.original_ordered_item_id;
            lr_oe_order_lines_history.original_inventory_item_id       :=
                pr_oe_order_lines.original_inventory_item_id;
            lr_oe_order_lines_history.accounting_rule_duration         :=
                pr_oe_order_lines.accounting_rule_duration;
            lr_oe_order_lines_history.attribute16                      :=
                pr_oe_order_lines.attribute16;
            lr_oe_order_lines_history.attribute17                      :=
                pr_oe_order_lines.attribute17;
            lr_oe_order_lines_history.attribute18                      :=
                pr_oe_order_lines.attribute18;
            lr_oe_order_lines_history.attribute19                      :=
                pr_oe_order_lines.attribute19;
            lr_oe_order_lines_history.attribute20                      :=
                pr_oe_order_lines.attribute20;
            lr_oe_order_lines_history.user_item_description            :=
                pr_oe_order_lines.user_item_description;
            lr_oe_order_lines_history.item_relationship_type           :=
                pr_oe_order_lines.item_relationship_type;
            lr_oe_order_lines_history.blanket_number                   :=
                pr_oe_order_lines.blanket_number;
            lr_oe_order_lines_history.blanket_line_number              :=
                pr_oe_order_lines.blanket_line_number;
            lr_oe_order_lines_history.blanket_version_number           :=
                pr_oe_order_lines.blanket_version_number;
            lr_oe_order_lines_history.sales_document_type_code         :=
                pr_oe_order_lines.sales_document_type_code;
            lr_oe_order_lines_history.transaction_phase_code           :=
                pr_oe_order_lines.transaction_phase_code;
            lr_oe_order_lines_history.source_document_version_number   :=
                pr_oe_order_lines.source_document_version_number;
            lr_oe_order_lines_history.end_customer_id                  :=
                pr_oe_order_lines.end_customer_id;
            lr_oe_order_lines_history.end_customer_contact_id          :=
                pr_oe_order_lines.end_customer_contact_id;
            lr_oe_order_lines_history.end_customer_site_use_id         :=
                pr_oe_order_lines.end_customer_site_use_id;
            lr_oe_order_lines_history.ib_owner                         :=
                pr_oe_order_lines.ib_owner;
            lr_oe_order_lines_history.ib_current_location              :=
                pr_oe_order_lines.ib_current_location;
            lr_oe_order_lines_history.ib_installed_at_location         :=
                pr_oe_order_lines.ib_installed_at_location;
            lr_oe_order_lines_history.audit_flag                       := 'Y';
            lr_oe_order_lines_history.reason_id                        :=
                pn_reason_id;
            lr_oe_order_lines_history.retrobill_request_id             :=
                pr_oe_order_lines.retrobill_request_id;
            lr_oe_order_lines_history.original_list_price              :=
                pr_oe_order_lines.original_list_price;
            lr_oe_order_lines_history.minisite_id                      :=
                pr_oe_order_lines.minisite_id;
            lr_oe_order_lines_history.payment_type_code                :=
                pr_oe_order_lines.payment_type_code;
            lr_oe_order_lines_history.firm_demand_flag                 :=
                pr_oe_order_lines.firm_demand_flag;
            lr_oe_order_lines_history.earliest_ship_date               :=
                pr_oe_order_lines.earliest_ship_date;
            lr_oe_order_lines_history.service_credit_eligible_code     :=
                pr_oe_order_lines.service_credit_eligible_code;
            lr_oe_order_lines_history.order_firmed_date                :=
                pr_oe_order_lines.order_firmed_date;
            lr_oe_order_lines_history.actual_fulfillment_date          :=
                pr_oe_order_lines.actual_fulfillment_date;
            lr_oe_order_lines_history.charge_periodicity_code          :=
                pr_oe_order_lines.charge_periodicity_code;
            lr_oe_order_lines_history.contingency_id                   :=
                pr_oe_order_lines.contingency_id;
            lr_oe_order_lines_history.revrec_event_code                :=
                pr_oe_order_lines.revrec_event_code;
            lr_oe_order_lines_history.revrec_expiration_days           :=
                pr_oe_order_lines.revrec_expiration_days;
            lr_oe_order_lines_history.accepted_quantity                :=
                pr_oe_order_lines.accepted_quantity;
            lr_oe_order_lines_history.accepted_by                      :=
                pr_oe_order_lines.accepted_by;
            lr_oe_order_lines_history.revrec_comments                  :=
                pr_oe_order_lines.revrec_comments;
            lr_oe_order_lines_history.revrec_reference_document        :=
                pr_oe_order_lines.revrec_reference_document;
            lr_oe_order_lines_history.revrec_signature                 :=
                pr_oe_order_lines.revrec_signature;
            lr_oe_order_lines_history.revrec_signature_date            :=
                pr_oe_order_lines.revrec_signature_date;
            lr_oe_order_lines_history.revrec_implicit_flag             :=
                pr_oe_order_lines.revrec_implicit_flag;
            lr_oe_order_lines_history.inst_id                          :=
                pr_oe_order_lines.inst_id;
            lr_oe_order_lines_history.service_bill_profile_id          :=
                pr_oe_order_lines.service_bill_profile_id;
            lr_oe_order_lines_history.service_cov_template_id          :=
                pr_oe_order_lines.service_cov_template_id;
            lr_oe_order_lines_history.service_subs_template_id         :=
                pr_oe_order_lines.service_subs_template_id;
            lr_oe_order_lines_history.service_bill_option_code         :=
                pr_oe_order_lines.service_bill_option_code;
            lr_oe_order_lines_history.service_first_period_amount      :=
                pr_oe_order_lines.service_first_period_amount;
            lr_oe_order_lines_history.service_first_period_enddate     :=
                pr_oe_order_lines.service_first_period_enddate;
            lr_oe_order_lines_history.subscription_enable_flag         :=
                pr_oe_order_lines.subscription_enable_flag;
            lr_oe_order_lines_history.container_number                 :=
                pr_oe_order_lines.container_number;
            lr_oe_order_lines_history.equipment_id                     :=
                pr_oe_order_lines.equipment_id;
        END IF;

        INSERT INTO oe_order_lines_history
             VALUES lr_oe_order_lines_history;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('OTHER Exception in create_order_line_history:' || SQLERRM,
                 1);
            xc_ret_stat   := g_ret_sts_error;
    END create_order_line_history;

    PROCEDURE update_msc_records (pr_order_line IN oe_order_lines_all%ROWTYPE, xc_ret_stat OUT VARCHAR2)
    AS
        lc_order_number         VARCHAR2 (100);
        lc_ret_stat             VARCHAR2 (1);
        ln_count                NUMBER;
        ln_ord_count            NUMBER;
        ln_msc_refresh_number   NUMBER;
        ln_msc_atp_session_id   NUMBER;

        PROCEDURE call_msc_prc (
            pr_order_line           IN     oe_order_lines_all%ROWTYPE,
            pc_order_number         IN     VARCHAR2,
            pn_msc_refresh_number   IN     NUMBER,
            pn_msc_atp_session_id   IN     NUMBER,
            xc_ret_stat                OUT VARCHAR2)
        AS
            PRAGMA AUTONOMOUS_TRANSACTION;
        BEGIN
            xxd_atp_customization_pkg.update_msc_records@BT_EBS_TO_ASCP.US.ORACLE.COM ( -- Added the full DB name for CCR0009529
                pr_order_line           => pr_order_line,
                pc_order_number         => pc_order_number,
                pn_msc_refresh_number   => pn_msc_refresh_number,
                pn_msc_atp_session_id   => pn_msc_atp_session_id,
                xc_ret_stat             => xc_ret_stat);
            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                COMMIT;
                msg ('OTHER Exception in call_msc_prc:' || SQLERRM, 1);
                xc_ret_stat   := g_ret_sts_error;
        END call_msc_prc;
    BEGIN
        SELECT ooha.order_number || '.' || otta.name || '.ORDER ENTRY(' || pr_order_line.line_number || '.' || pr_order_line.shipment_number || ')'
          INTO lc_order_number
          FROM oe_order_headers_all ooha, oe_transaction_types_tl otta
         WHERE     ooha.header_id = pr_order_line.header_id
               AND otta.transaction_type_id = ooha.order_type_id
               AND otta.language = USERENV ('LANG');

        ln_msc_refresh_number   := mrp_ap_refresh_s.NEXTVAL;
        ln_msc_atp_session_id   := mrp_atp_schedule_temp_s.NEXTVAL;

        msg ('Calling ASCP update_msc_records API');
        call_msc_prc (pr_order_line           => pr_order_line,
                      pc_order_number         => lc_order_number,
                      pn_msc_refresh_number   => ln_msc_refresh_number,
                      pn_msc_atp_session_id   => ln_msc_atp_session_id,
                      xc_ret_stat             => lc_ret_stat);
        msg ('ASCP update_msc_records API Status: ' || lc_ret_stat);
        xc_ret_stat             := lc_ret_stat;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('OTHER Exception in update_msc_records:' || SQLERRM, 1);
            xc_ret_stat   := g_ret_sts_error;
    END update_msc_records;

    PROCEDURE cancel_line_qty (pn_line_id IN NUMBER, pc_reason_code IN VARCHAR2, pc_comment IN VARCHAR2
                               , pn_cancel_quantity IN NUMBER, xn_cancelled_quantity OUT NUMBER, xc_ret_stat OUT VARCHAR2)
    AS
        lr_order_line   oe_order_lines_all%ROWTYPE;
        ln_reason_id    NUMBER;
        l_sqlrowcount   NUMBER := 0;
    BEGIN
        msg (
               'Line Id '
            || pn_line_id
            || ' Requested qty '
            || pn_cancel_quantity);
        xc_ret_stat             := g_ret_sts_success;
        lr_order_line           := lock_order_line (pn_line_id);
        xn_cancelled_quantity   :=
            LEAST (NVL (pn_cancel_quantity, 0),
                   NVL (lr_order_line.ordered_quantity, 0));

        IF NVL (xn_cancelled_quantity, 0) <= 0
        THEN
            xn_cancelled_quantity   := 0;
            msg ('Trying to capture 0 or fewer units; returning');
            RETURN;
        END IF;

        UPDATE oe_order_lines_all
           SET ordered_quantity           =
                   NVL (ordered_quantity, 0) - xn_cancelled_quantity,
               cancelled_quantity         =
                   NVL (cancelled_quantity, 0) + xn_cancelled_quantity,
               pricing_quantity           =
                   NVL (pricing_quantity, 0) - xn_cancelled_quantity,
               cancelled_flag            =
                   CASE
                       WHEN (NVL (ordered_quantity, 0) - xn_cancelled_quantity) >
                            0
                       THEN
                           'N'
                       ELSE
                           'Y'
                   END,
               open_flag                 =
                   CASE
                       WHEN (NVL (ordered_quantity, 0) - xn_cancelled_quantity) >
                            0
                       THEN
                           'Y'
                       ELSE
                           'N'
                   END,
               flow_status_code          =
                   CASE
                       WHEN (NVL (ordered_quantity, 0) - xn_cancelled_quantity) =
                            0
                       THEN
                           'CANCELLED'
                       ELSE
                           flow_status_code
                   END,
               visible_demand_flag       =
                   CASE
                       WHEN (NVL (ordered_quantity, 0) - xn_cancelled_quantity) =
                            0
                       THEN
                           NULL
                       ELSE
                           'Y'
                   END,                         -- Updated as Y for CCR0009505
               schedule_status_code      =
                   CASE
                       WHEN (NVL (ordered_quantity, 0) - xn_cancelled_quantity) =
                            0
                       THEN
                           NULL
                       ELSE
                           'SCHEDULED'
                   END,                                -- Added for CCR0009505
               last_update_date           = SYSDATE,
               shipping_interfaced_flag   = 'N',       -- Added for CCR0010401
               last_updated_by            = fnd_global.user_id
         WHERE line_id = lr_order_line.line_id;

        l_sqlrowcount           := SQL%ROWCOUNT;
        msg (
               'Captured '
            || xn_cancelled_quantity
            || ' having updated ('
            || l_sqlrowcount
            || ') rows with line_id ('
            || lr_order_line.line_id
            || ')');

        IF l_sqlrowcount = 0
        THEN
            xn_cancelled_Quantity   := 0;
            msg ('returning due to failing to update any records');
            RETURN;
        ELSIF l_sqlrowcount > 1
        THEN
            msg ('Raising exception; update changed too many rows');
            RAISE TOO_MANY_ROWS;
        END IF;

        IF xc_ret_stat = g_ret_sts_success
        THEN
            msg ('create oe reason');
            create_oe_reason (pn_line_id       => pn_line_id,
                              pc_reason_type   => 'CANCEL_CODE',
                              pc_reason_code   => pc_reason_code,
                              pc_comment       => pc_comment,
                              xn_reason_id     => ln_reason_id,
                              xc_ret_stat      => xc_ret_stat);
        END IF;

        IF xc_ret_stat = g_ret_sts_success
        THEN
            msg ('create order line history');
            create_order_line_history (
                pr_oe_order_lines    => lr_order_line,
                pn_cancel_quantity   => xn_cancelled_quantity,
                pn_reason_id         => ln_reason_id,
                pc_hist_type_code    => 'CANCELLATION',
                xc_ret_stat          => xc_ret_stat);
        END IF;

        IF xc_ret_stat = g_ret_sts_success
        THEN
            msg ('Fetch bulk Order Line as record');
            lr_order_line   := lock_order_line (pn_line_id);
            msg ('update MSC records');
            update_msc_records (pr_order_line   => lr_order_line,
                                xc_ret_stat     => xc_ret_stat);
        END IF;

        IF    xc_ret_stat IS NULL
           OR xc_ret_stat = g_miss_char
           OR xc_ret_stat != g_ret_sts_success
        THEN
            msg (
                   'setting xn_cancelled_quantity to 0 because xc_ret_stat was ('
                || xc_ret_stat
                || ')');
            xn_cancelled_quantity   := 0;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('OTHER Exception in cancel_line_qty:' || SQLERRM, 1);
            xc_ret_stat   := g_ret_sts_error;
    END cancel_line_qty;

    PROCEDURE get_poh_details (
        pn_inventory_item_id   IN     NUMBER,
        pn_organization_id     IN     NUMBER,
        pn_line_id             IN     NUMBER,
        xt_poh_details            OUT xxd_ont_poh_t_obj,
        xc_ret_stat               OUT VARCHAR2)
    AS
        ln_plan_id             NUMBER;
        ln_inventory_item_id   NUMBER;
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        xc_ret_stat   := g_ret_sts_success;

        BEGIN
            COMMIT;

            SELECT plan_id
              INTO ln_plan_id
              FROM apps.msc_plans@BT_EBS_TO_ASCP.US.ORACLE.COM mp -- Added the full DB name for CCR0009529
             WHERE mp.compile_designator = 'ATP';

            SELECT inventory_item_id
              INTO ln_inventory_item_id
              FROM apps.msc_system_items@BT_EBS_TO_ASCP.US.ORACLE.COM msi -- Added the full DB name for CCR0009529
             WHERE     msi.plan_id = ln_plan_id
                   AND msi.organization_id = pn_organization_id
                   AND msi.sr_inventory_item_id = pn_inventory_item_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                COMMIT;
                msg ('Exception in getting ASCP details:' || SQLERRM, 1);
                RETURN;
        END;

        BEGIN
            SELECT xxd_ont_poh_obj (supply_date, atp, undemand_atp,
                                    dependent_quantity)
              BULK COLLECT INTO xt_poh_details
              FROM (SELECT DISTINCT MIN (dte) OVER (PARTITION BY organization_id, inventory_item_id, supply_number) supply_date, LEAST (MIN (poh) OVER (PARTITION BY organization_id, inventory_item_id ORDER BY dte DESC RANGE UNBOUNDED PRECEDING), 100000000000) atp, LEAST (MIN (undemand_poh) OVER (PARTITION BY organization_id, inventory_item_id ORDER BY dte DESC RANGE UNBOUNDED PRECEDING), 100000000000) undemand_atp,
                                    LEAST (MIN (undemand_poh) OVER (PARTITION BY organization_id, inventory_item_id ORDER BY dte DESC RANGE UNBOUNDED PRECEDING), 100000000000) - LEAST (MIN (poh) OVER (PARTITION BY organization_id, inventory_item_id ORDER BY dte DESC RANGE UNBOUNDED PRECEDING), 100000000000) dependent_quantity
                      FROM (  SELECT organization_id, inventory_item_id, dte,
                                     SUM (SUM (quantity)) OVER (PARTITION BY organization_id, inventory_item_id ORDER BY dte RANGE UNBOUNDED PRECEDING) poh, SUM (SUM (undemand_quantity)) OVER (PARTITION BY organization_id, inventory_item_id ORDER BY dte RANGE UNBOUNDED PRECEDING) undemand_poh, SUM (SUM (supply_indicator)) OVER (PARTITION BY organization_id, inventory_item_id ORDER BY dte RANGE UNBOUNDED PRECEDING) supply_number
                                FROM (SELECT ms.organization_id, ms.inventory_item_id, GREATEST (TRUNC (NVL (ms.firm_date, ms.new_schedule_date)), TRUNC (SYSDATE)) dte,
                                             ms.new_order_quantity quantity, ms.new_order_quantity undemand_quantity, 1 supply_indicator
                                        FROM apps.msc_supplies@BT_EBS_TO_ASCP.US.ORACLE.COM ms -- Added the full DB name for CCR0009529
                                       WHERE     ms.plan_id = ln_plan_id
                                             AND ms.organization_id =
                                                 pn_organization_id
                                             AND ms.inventory_item_id =
                                                 ln_inventory_item_id
                                      UNION ALL
                                      SELECT md.organization_id,
                                             md.inventory_item_id,
                                             GREATEST (
                                                 TRUNC (schedule_ship_date),
                                                 TRUNC (SYSDATE))
                                                 dte,
                                             -using_requirement_quantity
                                                 quantity,
                                             CASE
                                                 WHEN NVL (pn_line_id, 0) =
                                                      md.sales_order_line_id
                                                 THEN
                                                     0
                                                 ELSE
                                                     -using_requirement_quantity
                                             END
                                                 undemand_quantity,
                                             0
                                                 supply_indicator
                                        FROM apps.msc_demands@BT_EBS_TO_ASCP.US.ORACLE.COM md -- Added the full DB name for CCR0009529
                                       WHERE     md.plan_id = ln_plan_id
                                             AND md.origination_type = 30
                                             AND md.schedule_ship_date
                                                     IS NOT NULL
                                             AND md.organization_id =
                                                 pn_organization_id
                                             AND md.inventory_item_id =
                                                 ln_inventory_item_id)
                            GROUP BY organization_id, inventory_item_id, dte))
             WHERE undemand_atp < 10000000000;

            COMMIT;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                msg ('No data found in POH query', 1);
            WHEN OTHERS
            THEN
                COMMIT;
                msg ('Unexpected error in POH query ' || SQLERRM, 1);
                RETURN;
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Exception in get_poh_details:' || SQLERRM, 1);
            xc_ret_stat   := g_ret_sts_error;
    END get_poh_details;

    -- Start changes for CCR0009567
    PROCEDURE update_order_header (p_header_id IN NUMBER)
    AS
        ln_count   NUMBER;
    BEGIN
        SELECT COUNT (1)
          INTO ln_count
          FROM oe_order_headers_all
         WHERE header_id = p_header_id AND open_flag = 'Y';

        IF ln_count = 0
        THEN
            UPDATE oe_order_headers_all
               SET open_flag = 'Y', cancelled_flag = 'N', flow_status_code = 'BOOKED',
                   last_update_date = SYSDATE, last_updated_by = fnd_global.user_id
             WHERE header_id = p_header_id;
        ELSE
            msg ('Bulk Order Header is Open. No changes needed');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Exception in update_order_header:' || SQLERRM, 1);
    END update_order_header;

    -- End changes for CCR0009567

    -- Start of Change for CCR0010423

    FUNCTION skip_add_unsched_lines (pn_old_bulk_line_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_brand                oe_order_headers_all.attribute5%TYPE;
        lv_sales_channel_code   oe_order_headers_all.sales_channel_code%TYPE;
        lr_old_bulk_line        oe_order_lines_all%ROWTYPE;
        lr_bulk_header          oe_order_headers_all%ROWTYPE;
        ln_skip_new_line_cnt    NUMBER;
        lv_return_flag          VARCHAR2 (10);
    BEGIN
        BEGIN
            SELECT *
              INTO lr_old_bulk_line
              FROM apps.oe_order_lines_all
             WHERE line_id = pn_old_bulk_line_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lr_old_bulk_line   := NULL;
                lv_return_flag     := 'N';
                msg (
                       ' OTHER Exception in skip_add_unsched_lines when fetching details for pn_old_bulk_line_id: '
                    || pn_old_bulk_line_id
                    || ' and error is: '
                    || SQLERRM,
                    1);
        END;

        BEGIN
            SELECT attribute5, sales_channel_code
              INTO lv_brand, lv_sales_channel_code
              FROM apps.oe_order_headers_all
             WHERE header_id = lr_old_bulk_line.header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_brand                := NULL;
                lv_sales_channel_code   := NULL;
                lv_return_flag          := 'N';
                msg (
                       ' OTHER Exception in skip_add_unsched_lines when fetching details for lr_old_bulk_line.header_id: '
                    || lr_old_bulk_line.header_id
                    || ' and error is: '
                    || SQLERRM,
                    1);
        END;

        SELECT COUNT (1)
          INTO ln_skip_new_line_cnt
          FROM apps.fnd_lookup_values
         WHERE     1 = 1
               AND language = 'US'
               AND lookup_type = 'XXD_ONT_ALT_GSA_UNCONSUMPTION'
               AND enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                               AND NVL (end_date_active, SYSDATE + 1)
               AND attribute1 = lr_old_bulk_line.org_id
               AND NVL (attribute2, NVL (lv_sales_channel_code, 'AAA')) =
                   NVL (lv_sales_channel_code, 'AAA')
               AND NVL (attribute3, lr_old_bulk_line.ship_from_org_id) =
                   lr_old_bulk_line.ship_from_org_id
               AND NVL (attribute4, lv_brand) = lv_brand;

        IF ln_skip_new_line_cnt > 0
        THEN
            lv_return_flag   := 'Y';
        ELSE
            lv_return_flag   := 'N';
        END IF;

        RETURN lv_return_flag;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_return_flag   := 'N';
            RETURN lv_return_flag;
    END skip_add_unsched_lines;

    -- End of Change for CCR0010423

    PROCEDURE create_new_line (p_old_bulk_line_id   IN     NUMBER,
                               p_ordered_qty        IN     NUMBER,
                               p_new_line_lad       IN     DATE,
                               p_bulk_org_ssd       IN     DATE DEFAULT NULL, -- ver 1.9
                               xc_ret_stat             OUT VARCHAR2)
    AS
        lr_bulk_line                  oe_order_lines_all%ROWTYPE;
        lr_new_line                   oe_order_lines_all%ROWTYPE;
        lr_old_bulk_line              oe_order_lines_all%ROWTYPE;
        lr_bulk_header                oe_order_headers_all%ROWTYPE;
        lr_new_item_attribute_value   applsys.wf_item_attribute_values%ROWTYPE;
        lr_new_item_status            applsys.wf_item_activity_statuses%ROWTYPE;
        lr_new_item                   applsys.wf_items%ROWTYPE;
        ln_line_id                    NUMBER;
        ln_ship_number                NUMBER;
        lc_ret_stat                   VARCHAR2 (10);
        ln_skip_new_line_cnt          NUMBER;       -- Added as per CCR0010423
        l_lad_offset                  NUMBER;
    BEGIN
        -- Added as per CCR0010423
        IF     p_new_line_lad IS NULL
           AND skip_add_unsched_lines (p_old_bulk_line_id) = 'Y'
        THEN
            msg (
                'New_Line_LAD is NULL and Satisfied lookup, So Return without Order Line data insertion');
            RETURN;
        END IF;

        -- End of Change for CCR0010423

        SELECT *
          INTO lr_old_bulk_line
          FROM oe_order_lines_all
         WHERE line_id = p_old_bulk_line_id;

        SELECT MAX (line_id)
          INTO ln_line_id
          FROM oe_order_lines_all
         WHERE     inventory_item_id = lr_old_bulk_line.inventory_item_id
               AND ship_from_org_id = lr_old_bulk_line.ship_from_org_id
               AND header_id = lr_old_bulk_line.header_id
               AND TRUNC (GREATEST (schedule_ship_date, SYSDATE)) =
                   TRUNC (GREATEST (p_new_line_lad, SYSDATE));

        msg ('Existing Bulk Line ID to update: ' || ln_line_id);

        IF     ln_line_id IS NOT NULL
           AND TRUNC (p_bulk_org_ssd) >= TRUNC (SYSDATE)
        THEN
            UPDATE oe_order_lines_all
               SET ordered_quantity           =
                       NVL (ordered_quantity, 0) + p_ordered_qty,
                   cancelled_flag            =
                       CASE
                           WHEN (NVL (ordered_quantity, 0) + p_ordered_qty) >
                                0
                           THEN
                               'N'
                           ELSE
                               'Y'
                       END,
                   cancelled_quantity        =
                       GREATEST (
                           (NVL (cancelled_quantity, 0) - p_ordered_qty),
                           0),
                   pricing_quantity           =
                       NVL (pricing_quantity, 0) + p_ordered_qty,
                   open_flag                 =
                       CASE
                           WHEN (NVL (ordered_quantity, 0) + p_ordered_qty) >
                                0
                           THEN
                               'Y'
                           ELSE
                               'N'
                       END,
                   flow_status_code          =
                       CASE
                           WHEN NVL (ordered_quantity, 0) + p_ordered_qty > 0
                           THEN
                               'AWAITING_SHIPPING'
                           ELSE
                               flow_status_code
                       END,
                   visible_demand_flag       =
                       CASE
                           WHEN NVL (ordered_quantity, 0) + p_ordered_qty > 0
                           THEN
                               'Y'
                           ELSE
                               NULL
                       END,
                   schedule_status_code      =
                       CASE
                           WHEN NVL (ordered_quantity, 0) + p_ordered_qty > 0
                           THEN
                               'SCHEDULED'
                           ELSE
                               NULL
                       END                             -- Added for CCR0009505
                          --, last_update_date = sysdate+1-1/(24*60) -- Commented for CCR0009550
                          --, last_update_date = trunc (sysdate)-1/(24*60) -- Added for CCR0009550
                          ,
                   last_update_date           = SYSDATE -- Added for CCR0009567
                                                       ,
                   shipping_interfaced_flag   = 'N'    -- Added for CCR0010401
                                                   ,
                   last_updated_by            = fnd_global.user_id
             WHERE line_id = ln_line_id;

            msg ('Successfully updated the existing Bulk Line ID');
            lr_new_line   := lock_order_line (ln_line_id);
            update_msc_records (pr_order_line   => lr_new_line,
                                xc_ret_stat     => lc_ret_stat);
            msg ('MSC record creation status: ' || lc_ret_stat);
            xc_ret_stat   := lc_ret_stat;
        ELSE
            -- begin 1.9
            -- get the lad date offset from the lookup
            BEGIN
                SELECT TO_NUMBER (lookup_code)
                  INTO l_lad_offset
                  FROM apps.fnd_lookup_values
                 WHERE     1 = 1
                       AND language = 'US'
                       AND lookup_type = 'XXD_ONT_GSA_LAD_EXT_LIMIT'
                       AND enabled_flag = 'Y'
                       AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                                       AND NVL (end_date_active, SYSDATE + 1);
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_lad_offset   := 10;
            END;

            -- end 1.9
            ln_line_id                                  := oe_order_lines_s.NEXTVAL;
            msg ('New Order Line ID: ' || ln_line_id);

            SELECT *
              INTO lr_bulk_line
              FROM ont.oe_order_lines_all
             WHERE line_id = p_old_bulk_line_id;

            SELECT *
              INTO lr_bulk_header
              FROM ont.oe_order_headers_all
             WHERE header_id = lr_bulk_line.header_id;

            lr_new_line                                 := lr_bulk_line;

            SELECT MAX (shipment_number) + 1
              INTO lr_new_line.shipment_number
              FROM ont.oe_order_lines_all
             WHERE     header_id = lr_bulk_line.header_id
                   AND line_number = lr_bulk_line.line_number;

            lr_new_line.line_id                         := ln_line_id;
            lr_new_line.request_date                    :=
                NVL (LEAST (lr_new_line.request_date, p_new_line_lad),
                     lr_new_line.request_date);
            --lr_new_line.latest_acceptable_date := nvl (greatest (lr_new_line.latest_acceptable_date, p_new_line_lad + 7), lr_new_line.latest_acceptable_date); -- ver 1.9 commented
            lr_new_line.latest_acceptable_date          :=
                NVL (
                    GREATEST (lr_new_line.latest_acceptable_date,
                              p_new_line_lad + l_lad_offset),
                    lr_new_line.latest_acceptable_date);      -- ver 1.9 added
            lr_new_line.flow_status_code                := 'AWAITING_SHIPPING';
            lr_new_line.schedule_ship_date              :=
                p_new_line_lad + 1 - 1 / (24 * 60);
            lr_new_line.schedule_arrival_date           :=
                p_new_line_lad + 1 - 1 / (24 * 60);
            -- lr_new_line.schedule_arrival_date := NULL; -- ver 1.9 commented; seems this was mistakently kept; above statement is setting it with the current value.
            lr_new_line.schedule_status_code            :=
                CASE
                    WHEN p_new_line_lad IS NOT NULL THEN 'SCHEDULED'
                    ELSE NULL
                END;
            lr_new_line.visible_demand_flag             :=
                CASE
                    WHEN p_new_line_lad IS NOT NULL THEN 'Y'
                    ELSE NULL
                END;                                   -- Added for CCR0009505
            lr_new_line.invoice_interface_status_code   := 'NOT_ELIGIBLE'; -- Added for CCR0009505
            lr_new_line.ordered_quantity                := p_ordered_qty;
            lr_new_line.pricing_quantity                := p_ordered_qty;
            lr_new_line.cancelled_quantity              := 0;
            lr_new_line.cancelled_flag                  := 'N';
            lr_new_line.open_flag                       := 'Y';
            lr_new_line.split_from_line_id              := p_old_bulk_line_id;
            lr_new_line.split_by                        := 'USER';
            lr_new_line.shipping_interfaced_flag        := 'N';
            lr_new_line.creation_date                   := SYSDATE;
            lr_new_line.created_by                      := fnd_global.user_id;
            lr_new_line.last_update_date                := SYSDATE;
            lr_new_line.last_updated_by                 := fnd_global.user_id;
            lr_new_line.last_update_login               :=
                fnd_global.login_id;
            -- Start changes for CCR0009669
            -- lr_new_line.orig_sys_line_ref := 'OE_ORDER_LINES_ALL'||lr_bulk_line.line_id;
            lr_new_line.orig_sys_line_ref               :=
                'OE_ORDER_LINES_ALL' || ln_line_id;

            -- End changes for CCR0009669

            INSERT INTO ont.oe_order_lines_all
                 VALUES lr_new_line;

            FOR rec
                IN (SELECT *
                      FROM applsys.wf_item_attribute_values
                     WHERE     item_type = 'OEOL'
                           AND item_key = TO_CHAR (lr_bulk_line.line_id))
            LOOP
                lr_new_item_attribute_value   := rec;
                lr_new_item_attribute_value.item_key   :=
                    TO_CHAR (ln_line_id);

                INSERT INTO applsys.wf_item_attribute_values
                     VALUES lr_new_item_attribute_value;
            END LOOP;

            FOR rec
                IN (SELECT *
                      FROM applsys.wf_item_activity_statuses
                     WHERE     item_type = 'OEOL'
                           AND item_key = TO_CHAR (lr_bulk_line.line_id))
            LOOP
                lr_new_item_status            := rec;
                lr_new_item_status.item_key   := TO_CHAR (ln_line_id);

                INSERT INTO applsys.wf_item_activity_statuses
                     VALUES lr_new_item_status;
            END LOOP;

            FOR rec
                IN (SELECT *
                      FROM applsys.wf_items
                     WHERE     item_type = 'OEOL'
                           AND item_key = TO_CHAR (lr_bulk_line.line_id))
            LOOP
                lr_new_item            := rec;
                lr_new_item.item_key   := TO_CHAR (ln_line_id);
                lr_new_item.user_key   :=
                       'Sales Order '
                    || lr_bulk_header.order_number
                    || '. Line '
                    || lr_new_line.line_number
                    || '.'
                    || lr_new_line.shipment_number
                    || '..';

                INSERT INTO applsys.wf_items
                     VALUES lr_new_item;
            END LOOP;

            msg ('Fetch new Order Line as record');

            IF p_new_line_lad IS NOT NULL
            THEN
                lr_new_line   := lock_order_line (ln_line_id);
                update_msc_records (pr_order_line   => lr_new_line,
                                    xc_ret_stat     => lc_ret_stat);
                msg ('MSC record creation status: ' || lc_ret_stat);
                xc_ret_stat   := lc_ret_stat;
            ELSE
                xc_ret_stat   := g_ret_sts_success;
                msg ('New line LAD is null. Skipping MSC creation');
            END IF;
        END IF;

        IF    xc_ret_stat IS NULL
           OR xc_ret_stat = g_miss_char
           OR xc_ret_stat != g_ret_sts_success
        THEN
            msg (
                   'setting xn_cancelled_quantity to 0 because xc_ret_stat was ('
                || xc_ret_stat
                || ')');
            RETURN;
        ELSE
            msg ('Adding New Bulk Line ID it to exclusion list');
            xxd_ont_bulk_calloff_pkg.add_line_id_to_exclusion (
                pn_line_id             => lr_new_line.line_id,
                pn_inventory_item_id   => lr_new_line.inventory_item_id,
                pn_priority            => 1);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Exception in create_new_line:' || SQLERRM, 1);
            xc_ret_stat   := g_ret_sts_error;
    END create_new_line;

    PROCEDURE create_update_line (pn_bulk_line_id      IN     NUMBER,
                                  pn_bulk_qty          IN     NUMBER,
                                  pn_calloff_line_id   IN     NUMBER,
                                  pd_calloff_old_ssd   IN     DATE,
                                  xc_ret_stat             OUT VARCHAR2)
    AS
        xxd_poh_t                xxd_ont_poh_t_obj;
        lr_bulk_line             oe_order_lines_all%ROWTYPE;
        lc_ret_stat              VARCHAR2 (10);
        lc_new_line_ret_stat     VARCHAR2 (10);
        ln_undemand_qty          NUMBER := 0;
        ln_new_qty               NUMBER := 0;
        ln_pending_qty           NUMBER := 0;
        ln_replace_qty           NUMBER := 0;
        ln_inventory_item_id     NUMBER;
        ln_organization_id       NUMBER;
        ln_bulk_header_id        NUMBER;               -- Added for CCR0009567
        ld_bulk_ssd              DATE;
        ld_orig_bulk_ssd         DATE;                 -- Added for CCR0009692
        ld_calloff_old_ssd       DATE := pd_calloff_old_ssd;
        l_skip_create_new_Line   VARCHAR2 (1)
            := NVL (fnd_profile.VALUE ('XXD_ONT_GSA_SKIP_CREATE_LINE'), 'Y'); -- VER 1.9
        l_bulk_lad               DATE;                              -- ver 1.9
    BEGIN
        BEGIN
            SELECT inventory_item_id, ship_from_org_id
              INTO ln_inventory_item_id, ln_organization_id
              FROM oe_order_lines_all
             WHERE line_id = pn_calloff_line_id;

            -- Start changes for CCR0009692
            -- select trunc (greatest (schedule_ship_date, sysdate)), header_id into ld_bulk_ssd, ln_bulk_header_id -- Added header_id for CCR0009567
            SELECT TRUNC (NVL (schedule_ship_date, request_date)), header_id, schedule_ship_date,
                   latest_acceptable_date
              INTO ld_bulk_ssd, ln_bulk_header_id, ld_orig_bulk_ssd, l_bulk_lad
              -- End changes for CCR0009692
              FROM oe_order_lines_all
             WHERE line_id = pn_bulk_line_id;

            msg ('Original Bulk SSD: ' || ld_bulk_ssd);
        EXCEPTION
            WHEN OTHERS
            THEN
                msg ('Exception in getting line details:' || SQLERRM, 1);
                RETURN;
        END;

        update_order_header (ln_bulk_header_id);       -- Added for CCR0009567

        get_poh_details (pn_inventory_item_id   => ln_inventory_item_id,
                         pn_organization_id     => ln_organization_id,
                         pn_line_id             => pn_calloff_line_id,
                         xt_poh_details         => xxd_poh_t,
                         xc_ret_stat            => lc_ret_stat);

        IF lc_ret_stat <> g_ret_sts_success
        THEN
            RETURN;
        ELSE
            msg ('Got POH details');
            ln_pending_qty    := pn_bulk_qty;

            FOR i IN (  SELECT *
                          FROM TABLE (xxd_poh_t)
                      ORDER BY supply_date)
            LOOP
                msg (
                    'POH Details = ' || i.supply_date || ' with qty = ' || i.undemand_atp);

                IF i.supply_date <= ld_bulk_ssd
                THEN
                    ln_undemand_qty   := i.undemand_atp;
                    msg (
                           'Supply Date is less than Bulk SSD. Setting Undemand Qty for this supply date as '
                        || ln_undemand_qty);
                END IF;
            END LOOP;

            ln_undemand_qty   := NVL (ln_undemand_qty, 0);
            msg ('ln_undemand_qty = ' || ln_undemand_qty);

            IF ln_undemand_qty <= 0
            THEN
                msg (
                       'No changes are needed to the Original Bulk Line ID: '
                    || pn_bulk_line_id);
            ELSIF     ld_orig_bulk_ssd IS NOT NULL
                  AND TRUNC (ld_orig_bulk_ssd) >= TRUNC (SYSDATE)
            THEN          -- Added ld_orig_bulk_ssd IS NOT NULL for CCR0009692
                ln_new_qty     := LEAST (ln_undemand_qty, pn_bulk_qty);

                IF ln_new_qty < 0
                THEN
                    ln_new_qty   := pn_bulk_qty;
                END IF;

                msg (
                       'Running through unconsumption with qty as '
                    || ln_new_qty);
                lr_bulk_line   := lock_order_line (pn_bulk_line_id);
                create_order_line_history (
                    pr_oe_order_lines    => lr_bulk_line,
                    pn_cancel_quantity   => 0,
                    pn_reason_id         => NULL,
                    pc_hist_type_code    => 'UPDATE',
                    xc_ret_stat          => lc_ret_stat);
                msg (
                       'Created OOLA history in Update mode with original qty with status: '
                    || lc_ret_stat);

                UPDATE oe_order_lines_all
                   SET ordered_quantity           =
                           NVL (ordered_quantity, 0) + ln_new_qty,
                       cancelled_flag            =
                           CASE
                               WHEN (NVL (ordered_quantity, 0) + ln_new_qty) >
                                    0
                               THEN
                                   'N'
                               ELSE
                                   'Y'
                           END,
                       cancelled_quantity        =
                           GREATEST (
                               (NVL (cancelled_quantity, 0) - ln_new_qty),
                               0),
                       pricing_quantity           =
                           NVL (pricing_quantity, 0) + ln_new_qty,
                       open_flag                 =
                           CASE
                               WHEN (NVL (ordered_quantity, 0) + ln_new_qty) >
                                    0
                               THEN
                                   'Y'
                               ELSE
                                   'N'
                           END,
                       flow_status_code          =
                           CASE
                               WHEN NVL (ordered_quantity, 0) + ln_new_qty >
                                    0
                               THEN
                                   'AWAITING_SHIPPING'
                               ELSE
                                   flow_status_code
                           END,
                       visible_demand_flag       =
                           CASE
                               WHEN NVL (ordered_quantity, 0) + ln_new_qty >
                                    0
                               THEN
                                   'Y'
                               ELSE
                                   NULL
                           END,
                       schedule_status_code      =
                           CASE
                               WHEN NVL (ordered_quantity, 0) + ln_new_qty >
                                    0
                               THEN
                                   'SCHEDULED'
                               ELSE
                                   NULL
                           END                         -- Added for CCR0009505
                              --, last_update_date = sysdate+1-1/(24*60) -- Commented for CCR0009550
                              --, last_update_date = trunc (sysdate)-1/(24*60) -- Added for CCR0009550
                              ,
                       last_update_date           = SYSDATE -- Added for CCR0009567
                                                           ,
                       shipping_interfaced_flag   = 'N' -- Added for CCR0010401
                                                       ,
                       last_updated_by            = fnd_global.user_id
                 WHERE line_id = pn_bulk_line_id;

                msg ('Updated OOLA with qty as ' || ln_new_qty);
                lr_bulk_line   := lock_order_line (pn_bulk_line_id);
                msg (
                       'Fetch bulk Order Line as record for Line ID: '
                    || pn_bulk_line_id);
                update_msc_records (pr_order_line   => lr_bulk_line,
                                    xc_ret_stat     => lc_ret_stat);
                xc_ret_stat    := lc_ret_stat;

                IF    xc_ret_stat IS NULL
                   OR xc_ret_stat = g_miss_char
                   OR xc_ret_stat != g_ret_sts_success
                THEN
                    msg (
                           'setting xn_cancelled_quantity to 0 because xc_ret_stat was ('
                        || xc_ret_stat
                        || ')');
                    RETURN;
                ELSIF xc_ret_stat = g_ret_sts_success
                THEN
                    msg (
                           'Updated MSC with qty as '
                        || ln_new_qty
                        || ' and status: '
                        || lc_ret_stat);
                    ln_pending_qty   := ln_pending_qty - ln_new_qty;
                    ln_replace_qty   := ln_replace_qty + ln_new_qty;
                END IF;
            END IF;

            IF ln_pending_qty > 0
            THEN
                msg (
                       'Updating/Creating new order lines for all pending qty: '
                    || ln_pending_qty
                    || ' with replace qty: '
                    || ln_replace_qty
                    || ' :ld_calloff_old_ssd:-'
                    || ld_calloff_old_ssd
                    || ':ld_bulk_ssd:-'
                    || ld_bulk_ssd);

                -- ver begin 1.9 if bulk lad is in the past then consider sysdate
                IF l_bulk_lad < TRUNC (SYSDATE)
                THEN
                    l_bulk_lad   := TRUNC (SYSDATE);
                END IF;

                -- ver end 1.9
                FOR poh_rec
                    IN (  SELECT *
                            FROM TABLE (xxd_poh_t)
                           WHERE     supply_date > ld_bulk_ssd --and supply_date <= ld_calloff_old_ssd  -- ver 1.9 commented
                                 AND supply_date <= l_bulk_lad -- ver 1.9 added this ; we have check the supply until we reaches bulk lad window
                        ORDER BY supply_date)
                LOOP
                    ln_new_qty   :=
                        LEAST (ln_pending_qty,
                               (poh_rec.undemand_atp - ln_replace_qty));

                    IF ln_new_qty > 0
                    THEN
                        --          msg ('Bulk Line will be updated/created with qty as '|| ln_new_qty || ' and LAD as Supply Date '|| poh_rec.supply_date);
                        msg (
                               'Bulk Line will be updated/created with qty as ln_new_qty: '
                            || ln_new_qty
                            || ' and LAD as Supply Date '
                            || poh_rec.supply_date
                            || ' and ln_pending_qty as : '
                            || ln_pending_qty
                            || ' and ld_bulk_ssd :'
                            || ld_bulk_ssd);
                        -- Create new line
                        create_new_line (
                            p_old_bulk_line_id   => pn_bulk_line_id,
                            p_ordered_qty        => ln_new_qty,
                            p_new_line_lad       =>
                                GREATEST (poh_rec.supply_date, ld_bulk_ssd), -- Added greatest condition with ld_bulk_ssd for CCR0009692
                            p_bulk_org_ssd       => ld_orig_bulk_ssd, -- ver 1.9
                            xc_ret_stat          => lc_new_line_ret_stat);

                        IF lc_new_line_ret_stat = g_ret_sts_success
                        THEN
                            ln_pending_qty   := ln_pending_qty - ln_new_qty;
                            ln_replace_qty   := ln_replace_qty + ln_new_qty;
                            EXIT WHEN ln_pending_qty = 0;
                        END IF;
                    END IF;
                END LOOP;
            ELSE
                msg (
                       'Pending Qty is '
                    || ln_pending_qty
                    || '. No new order line creation needed');
            END IF;

            IF gc_skip_neg_unconsumption = 'Y'
            THEN
                ld_calloff_old_ssd   := NULL;
            END IF;

            -- ver 1.9 begin (supress the code) below condition is not checking w.r.t to POH wheather that ld_calloff_old_ssd var is the right date to meet the demand or not.
            -- its the ssd date of the old bulk line and that is being used to create the new line and put that date as lad and ssd which is not valid in the current world as we dont want   the new BULK like to be created if that cant be scheduled. for a new line having the true scheduling, greatest (ld_calloff_old_ssd, ld_bulk_ssd) should factored in the POH query results and then decide.
            msg ('l_skip_create_new_Line:- ' || l_skip_create_new_Line);

            IF ln_pending_qty > 0 AND l_skip_create_new_Line = 'N'
            THEN                                                    -- VER 1.9
                --      msg ('Bulk Line will be updated/created with qty as '|| ln_pending_qty || ' and LAD as Calloff SSD '|| ld_calloff_old_ssd);
                msg (
                       'Bulk Line will be updated/created with qty as ln_pending_qty :'
                    || ln_pending_qty
                    || ' and LAD as Calloff SSD '
                    || ld_calloff_old_ssd
                    || ' and ld_bulk_ssd :'
                    || ld_bulk_ssd);
                -- Create new line
                create_new_line (p_old_bulk_line_id => pn_bulk_line_id, p_ordered_qty => ln_pending_qty, p_new_line_lad => GREATEST (ld_calloff_old_ssd, ld_bulk_ssd)
                                 , -- Added greatest condition with ld_bulk_ssd for CCR0009692
                                   xc_ret_stat => lc_new_line_ret_stat);

                IF lc_new_line_ret_stat != g_ret_sts_success
                THEN
                    msg ('New line creation failed');
                END IF;
            END IF;
        END IF;

        xc_ret_stat   := g_ret_sts_success;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Exception in create_update_line:' || SQLERRM, 1);
            xc_ret_stat   := g_ret_sts_error;
    END create_update_line;

    PROCEDURE increase_line_qty (pn_line_id IN NUMBER, pn_increase_quantity IN NUMBER, pn_calloff_line_id IN NUMBER
                                 , pd_calloff_old_ssd IN DATE, xn_increased_quantity OUT NUMBER, xc_ret_stat OUT VARCHAR2)
    AS
    BEGIN
        msg (
               'In increase_line_qty for pn_line_id = '
            || pn_line_id
            || ' with qty as '
            || pn_increase_quantity);

        IF pn_increase_quantity < 0
        THEN
            xc_ret_stat   := g_ret_sts_error;
            msg ('Increase Qty cannot be less than zero', 1);
            RETURN;
        END IF;

        create_update_line (pn_bulk_line_id      => pn_line_id,
                            pn_bulk_qty          => pn_increase_quantity,
                            pn_calloff_line_id   => pn_calloff_line_id,
                            pd_calloff_old_ssd   => pd_calloff_old_ssd,
                            xc_ret_stat          => xc_ret_stat);

        msg ('create_update_line call status: ' || xc_ret_stat);

        IF xc_ret_stat = g_ret_sts_success
        THEN
            xn_increased_quantity   := pn_increase_quantity;
        ELSE
            xc_ret_stat   := g_ret_sts_error;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Exception in increase_line_qty:' || SQLERRM, 1);
            xc_ret_stat   := g_ret_sts_error;
    END increase_line_qty;

    FUNCTION oola_obj_to_rec_fnc (p_obj xxd_ne.xxd_ont_ord_line_obj)
        RETURN oe_order_lines_all%ROWTYPE
    IS
        lr_new   oe_order_lines_all%ROWTYPE;
    BEGIN
        --select recs.rec||'.'||cols.column_name||' := ' || recs.s || '.' || cols.column_name || ';'
        --  from (select lower(column_name) column_name, column_id from all_Tab_columns where owner = 'ONT' and table_name = 'OE_ORDER_LINES_ALL' order by column_id asc) cols
        --     , (select 'lr_new' rec, 1 ord, 'p_obj' s from dual) recs
        --order by cols.column_id, recs.ord
        lr_new.line_id                          := p_obj.line_id;
        lr_new.org_id                           := p_obj.org_id;
        lr_new.header_id                        := p_obj.header_id;
        lr_new.line_type_id                     := p_obj.line_type_id;
        lr_new.line_number                      := p_obj.line_number;
        lr_new.ordered_item                     := p_obj.ordered_item;
        lr_new.request_date                     := p_obj.request_date;
        lr_new.promise_date                     := p_obj.promise_date;
        lr_new.schedule_ship_date               := p_obj.schedule_ship_date;
        lr_new.order_quantity_uom               := p_obj.order_quantity_uom;
        lr_new.pricing_quantity                 := p_obj.pricing_quantity;
        lr_new.pricing_quantity_uom             := p_obj.pricing_quantity_uom;
        lr_new.cancelled_quantity               := p_obj.cancelled_quantity;
        lr_new.shipped_quantity                 := p_obj.shipped_quantity;
        lr_new.ordered_quantity                 := p_obj.ordered_quantity;
        lr_new.fulfilled_quantity               := p_obj.fulfilled_quantity;
        lr_new.shipping_quantity                := p_obj.shipping_quantity;
        lr_new.shipping_quantity_uom            := p_obj.shipping_quantity_uom;
        lr_new.delivery_lead_time               := p_obj.delivery_lead_time;
        lr_new.tax_exempt_flag                  := p_obj.tax_exempt_flag;
        lr_new.tax_exempt_number                := p_obj.tax_exempt_number;
        lr_new.tax_exempt_reason_code           := p_obj.tax_exempt_reason_code;
        lr_new.ship_from_org_id                 := p_obj.ship_from_org_id;
        lr_new.ship_to_org_id                   := p_obj.ship_to_org_id;
        lr_new.invoice_to_org_id                := p_obj.invoice_to_org_id;
        lr_new.deliver_to_org_id                := p_obj.deliver_to_org_id;
        lr_new.ship_to_contact_id               := p_obj.ship_to_contact_id;
        lr_new.deliver_to_contact_id            := p_obj.deliver_to_contact_id;
        lr_new.invoice_to_contact_id            := p_obj.invoice_to_contact_id;
        lr_new.intmed_ship_to_org_id            := p_obj.intmed_ship_to_org_id;
        lr_new.intmed_ship_to_contact_id        := p_obj.intmed_ship_to_contact_id;
        lr_new.sold_from_org_id                 := p_obj.sold_from_org_id;
        lr_new.sold_to_org_id                   := p_obj.sold_to_org_id;
        lr_new.cust_po_number                   := p_obj.cust_po_number;
        lr_new.ship_tolerance_above             := p_obj.ship_tolerance_above;
        lr_new.ship_tolerance_below             := p_obj.ship_tolerance_below;
        lr_new.demand_bucket_type_code          := p_obj.demand_bucket_type_code;
        lr_new.veh_cus_item_cum_key_id          := p_obj.veh_cus_item_cum_key_id;
        lr_new.rla_schedule_type_code           := p_obj.rla_schedule_type_code;
        lr_new.customer_dock_code               := p_obj.customer_dock_code;
        lr_new.customer_job                     := p_obj.customer_job;
        lr_new.customer_production_line         := p_obj.customer_production_line;
        lr_new.cust_model_serial_number         := p_obj.cust_model_serial_number;
        lr_new.project_id                       := p_obj.project_id;
        lr_new.task_id                          := p_obj.task_id;
        lr_new.inventory_item_id                := p_obj.inventory_item_id;
        lr_new.tax_date                         := p_obj.tax_date;
        lr_new.tax_code                         := p_obj.tax_code;
        lr_new.tax_rate                         := p_obj.tax_rate;
        lr_new.invoice_interface_status_code    :=
            p_obj.invoice_interface_status_code;
        lr_new.demand_class_code                := p_obj.demand_class_code;
        lr_new.price_list_id                    := p_obj.price_list_id;
        lr_new.pricing_date                     := p_obj.pricing_date;
        lr_new.shipment_number                  := p_obj.shipment_number;
        lr_new.agreement_id                     := p_obj.agreement_id;
        lr_new.shipment_priority_code           :=
            p_obj.shipment_priority_code;
        lr_new.shipping_method_code             := p_obj.shipping_method_code;
        lr_new.freight_carrier_code             := p_obj.freight_carrier_code;
        lr_new.freight_terms_code               := p_obj.freight_terms_code;
        lr_new.fob_point_code                   := p_obj.fob_point_code;
        lr_new.tax_point_code                   := p_obj.tax_point_code;
        lr_new.payment_term_id                  := p_obj.payment_term_id;
        lr_new.invoicing_rule_id                := p_obj.invoicing_rule_id;
        lr_new.accounting_rule_id               := p_obj.accounting_rule_id;
        lr_new.source_document_type_id          :=
            p_obj.source_document_type_id;
        lr_new.orig_sys_document_ref            := p_obj.orig_sys_document_ref;
        lr_new.source_document_id               := p_obj.source_document_id;
        lr_new.orig_sys_line_ref                := p_obj.orig_sys_line_ref;
        lr_new.source_document_line_id          :=
            p_obj.source_document_line_id;
        lr_new.reference_line_id                := p_obj.reference_line_id;
        lr_new.reference_type                   := p_obj.reference_type;
        lr_new.reference_header_id              := p_obj.reference_header_id;
        lr_new.item_revision                    := p_obj.item_revision;
        lr_new.unit_selling_price               := p_obj.unit_selling_price;
        lr_new.unit_list_price                  := p_obj.unit_list_price;
        lr_new.tax_value                        := p_obj.tax_value;
        lr_new.context                          := p_obj.context;
        lr_new.attribute1                       := p_obj.attribute1;
        lr_new.attribute2                       := p_obj.attribute2;
        lr_new.attribute3                       := p_obj.attribute3;
        lr_new.attribute4                       := p_obj.attribute4;
        lr_new.attribute5                       := p_obj.attribute5;
        lr_new.attribute6                       := p_obj.attribute6;
        lr_new.attribute7                       := p_obj.attribute7;
        lr_new.attribute8                       := p_obj.attribute8;
        lr_new.attribute9                       := p_obj.attribute9;
        lr_new.attribute10                      := p_obj.attribute10;
        lr_new.attribute11                      := p_obj.attribute11;
        lr_new.attribute12                      := p_obj.attribute12;
        lr_new.attribute13                      := p_obj.attribute13;
        lr_new.attribute14                      := p_obj.attribute14;
        lr_new.attribute15                      := p_obj.attribute15;
        lr_new.global_attribute_category        :=
            p_obj.global_attribute_category;
        lr_new.global_attribute1                := p_obj.global_attribute1;
        lr_new.global_attribute2                := p_obj.global_attribute2;
        lr_new.global_attribute3                := p_obj.global_attribute3;
        lr_new.global_attribute4                := p_obj.global_attribute4;
        lr_new.global_attribute5                := p_obj.global_attribute5;
        lr_new.global_attribute6                := p_obj.global_attribute6;
        lr_new.global_attribute7                := p_obj.global_attribute7;
        lr_new.global_attribute8                := p_obj.global_attribute8;
        lr_new.global_attribute9                := p_obj.global_attribute9;
        lr_new.global_attribute10               := p_obj.global_attribute10;
        lr_new.global_attribute11               := p_obj.global_attribute11;
        lr_new.global_attribute12               := p_obj.global_attribute12;
        lr_new.global_attribute13               := p_obj.global_attribute13;
        lr_new.global_attribute14               := p_obj.global_attribute14;
        lr_new.global_attribute15               := p_obj.global_attribute15;
        lr_new.global_attribute16               := p_obj.global_attribute16;
        lr_new.global_attribute17               := p_obj.global_attribute17;
        lr_new.global_attribute18               := p_obj.global_attribute18;
        lr_new.global_attribute19               := p_obj.global_attribute19;
        lr_new.global_attribute20               := p_obj.global_attribute20;
        lr_new.pricing_context                  := p_obj.pricing_context;
        lr_new.pricing_attribute1               := p_obj.pricing_attribute1;
        lr_new.pricing_attribute2               := p_obj.pricing_attribute2;
        lr_new.pricing_attribute3               := p_obj.pricing_attribute3;
        lr_new.pricing_attribute4               := p_obj.pricing_attribute4;
        lr_new.pricing_attribute5               := p_obj.pricing_attribute5;
        lr_new.pricing_attribute6               := p_obj.pricing_attribute6;
        lr_new.pricing_attribute7               := p_obj.pricing_attribute7;
        lr_new.pricing_attribute8               := p_obj.pricing_attribute8;
        lr_new.pricing_attribute9               := p_obj.pricing_attribute9;
        lr_new.pricing_attribute10              := p_obj.pricing_attribute10;
        lr_new.industry_context                 := p_obj.industry_context;
        lr_new.industry_attribute1              := p_obj.industry_attribute1;
        lr_new.industry_attribute2              := p_obj.industry_attribute2;
        lr_new.industry_attribute3              := p_obj.industry_attribute3;
        lr_new.industry_attribute4              := p_obj.industry_attribute4;
        lr_new.industry_attribute5              := p_obj.industry_attribute5;
        lr_new.industry_attribute6              := p_obj.industry_attribute6;
        lr_new.industry_attribute7              := p_obj.industry_attribute7;
        lr_new.industry_attribute8              := p_obj.industry_attribute8;
        lr_new.industry_attribute9              := p_obj.industry_attribute9;
        lr_new.industry_attribute10             := p_obj.industry_attribute10;
        lr_new.industry_attribute11             := p_obj.industry_attribute11;
        lr_new.industry_attribute13             := p_obj.industry_attribute13;
        lr_new.industry_attribute12             := p_obj.industry_attribute12;
        lr_new.industry_attribute14             := p_obj.industry_attribute14;
        lr_new.industry_attribute15             := p_obj.industry_attribute15;
        lr_new.industry_attribute16             := p_obj.industry_attribute16;
        lr_new.industry_attribute17             := p_obj.industry_attribute17;
        lr_new.industry_attribute18             := p_obj.industry_attribute18;
        lr_new.industry_attribute19             := p_obj.industry_attribute19;
        lr_new.industry_attribute20             := p_obj.industry_attribute20;
        lr_new.industry_attribute21             := p_obj.industry_attribute21;
        lr_new.industry_attribute22             := p_obj.industry_attribute22;
        lr_new.industry_attribute23             := p_obj.industry_attribute23;
        lr_new.industry_attribute24             := p_obj.industry_attribute24;
        lr_new.industry_attribute25             := p_obj.industry_attribute25;
        lr_new.industry_attribute26             := p_obj.industry_attribute26;
        lr_new.industry_attribute27             := p_obj.industry_attribute27;
        lr_new.industry_attribute28             := p_obj.industry_attribute28;
        lr_new.industry_attribute29             := p_obj.industry_attribute29;
        lr_new.industry_attribute30             := p_obj.industry_attribute30;
        lr_new.creation_date                    := p_obj.creation_date;
        lr_new.created_by                       := p_obj.created_by;
        lr_new.last_update_date                 := p_obj.last_update_date;
        lr_new.last_updated_by                  := p_obj.last_updated_by;
        lr_new.last_update_login                := p_obj.last_update_login;
        lr_new.program_application_id           :=
            p_obj.program_application_id;
        lr_new.program_id                       := p_obj.program_id;
        lr_new.program_update_date              := p_obj.program_update_date;
        lr_new.request_id                       := p_obj.request_id;
        lr_new.top_model_line_id                := p_obj.top_model_line_id;
        lr_new.link_to_line_id                  := p_obj.link_to_line_id;
        lr_new.component_sequence_id            := p_obj.component_sequence_id;
        lr_new.component_code                   := p_obj.component_code;
        lr_new.config_display_sequence          :=
            p_obj.config_display_sequence;
        lr_new.sort_order                       := p_obj.sort_order;
        lr_new.item_type_code                   := p_obj.item_type_code;
        lr_new.option_number                    := p_obj.option_number;
        lr_new.option_flag                      := p_obj.option_flag;
        lr_new.dep_plan_required_flag           :=
            p_obj.dep_plan_required_flag;
        lr_new.visible_demand_flag              := p_obj.visible_demand_flag;
        lr_new.line_category_code               := p_obj.line_category_code;
        lr_new.actual_shipment_date             := p_obj.actual_shipment_date;
        lr_new.customer_trx_line_id             := p_obj.customer_trx_line_id;
        lr_new.return_context                   := p_obj.return_context;
        lr_new.return_attribute1                := p_obj.return_attribute1;
        lr_new.return_attribute2                := p_obj.return_attribute2;
        lr_new.return_attribute3                := p_obj.return_attribute3;
        lr_new.return_attribute4                := p_obj.return_attribute4;
        lr_new.return_attribute5                := p_obj.return_attribute5;
        lr_new.return_attribute6                := p_obj.return_attribute6;
        lr_new.return_attribute7                := p_obj.return_attribute7;
        lr_new.return_attribute8                := p_obj.return_attribute8;
        lr_new.return_attribute9                := p_obj.return_attribute9;
        lr_new.return_attribute10               := p_obj.return_attribute10;
        lr_new.return_attribute11               := p_obj.return_attribute11;
        lr_new.return_attribute12               := p_obj.return_attribute12;
        lr_new.return_attribute13               := p_obj.return_attribute13;
        lr_new.return_attribute14               := p_obj.return_attribute14;
        lr_new.return_attribute15               := p_obj.return_attribute15;
        lr_new.actual_arrival_date              := p_obj.actual_arrival_date;
        lr_new.ato_line_id                      := p_obj.ato_line_id;
        lr_new.auto_selected_quantity           :=
            p_obj.auto_selected_quantity;
        lr_new.component_number                 := p_obj.component_number;
        lr_new.earliest_acceptable_date         :=
            p_obj.earliest_acceptable_date;
        lr_new.explosion_date                   := p_obj.explosion_date;
        lr_new.latest_acceptable_date           :=
            p_obj.latest_acceptable_date;
        lr_new.model_group_number               := p_obj.model_group_number;
        lr_new.schedule_arrival_date            := p_obj.schedule_arrival_date;
        lr_new.ship_model_complete_flag         :=
            p_obj.ship_model_complete_flag;
        lr_new.schedule_status_code             := p_obj.schedule_status_code;
        lr_new.source_type_code                 := p_obj.source_type_code;
        lr_new.cancelled_flag                   := p_obj.cancelled_flag;
        lr_new.open_flag                        := p_obj.open_flag;
        lr_new.booked_flag                      := p_obj.booked_flag;
        lr_new.salesrep_id                      := p_obj.salesrep_id;
        lr_new.return_reason_code               := p_obj.return_reason_code;
        lr_new.arrival_set_id                   := p_obj.arrival_set_id;
        lr_new.ship_set_id                      := p_obj.ship_set_id;
        lr_new.split_from_line_id               := p_obj.split_from_line_id;
        lr_new.cust_production_seq_num          :=
            p_obj.cust_production_seq_num;
        lr_new.authorized_to_ship_flag          :=
            p_obj.authorized_to_ship_flag;
        lr_new.over_ship_reason_code            := p_obj.over_ship_reason_code;
        lr_new.over_ship_resolved_flag          :=
            p_obj.over_ship_resolved_flag;
        lr_new.ordered_item_id                  := p_obj.ordered_item_id;
        lr_new.item_identifier_type             := p_obj.item_identifier_type;
        lr_new.configuration_id                 := p_obj.configuration_id;
        lr_new.commitment_id                    := p_obj.commitment_id;
        lr_new.shipping_interfaced_flag         :=
            p_obj.shipping_interfaced_flag;
        lr_new.credit_invoice_line_id           :=
            p_obj.credit_invoice_line_id;
        lr_new.first_ack_code                   := p_obj.first_ack_code;
        lr_new.first_ack_date                   := p_obj.first_ack_date;
        lr_new.last_ack_code                    := p_obj.last_ack_code;
        lr_new.last_ack_date                    := p_obj.last_ack_date;
        lr_new.planning_priority                := p_obj.planning_priority;
        lr_new.order_source_id                  := p_obj.order_source_id;
        lr_new.orig_sys_shipment_ref            := p_obj.orig_sys_shipment_ref;
        lr_new.change_sequence                  := p_obj.change_sequence;
        lr_new.drop_ship_flag                   := p_obj.drop_ship_flag;
        lr_new.customer_line_number             := p_obj.customer_line_number;
        lr_new.customer_shipment_number         :=
            p_obj.customer_shipment_number;
        lr_new.customer_item_net_price          :=
            p_obj.customer_item_net_price;
        lr_new.customer_payment_term_id         :=
            p_obj.customer_payment_term_id;
        lr_new.fulfilled_flag                   := p_obj.fulfilled_flag;
        lr_new.end_item_unit_number             := p_obj.end_item_unit_number;
        lr_new.config_header_id                 := p_obj.config_header_id;
        lr_new.config_rev_nbr                   := p_obj.config_rev_nbr;
        lr_new.mfg_component_sequence_id        :=
            p_obj.mfg_component_sequence_id;
        lr_new.shipping_instructions            := p_obj.shipping_instructions;
        lr_new.packing_instructions             := p_obj.packing_instructions;
        lr_new.invoiced_quantity                := p_obj.invoiced_quantity;
        lr_new.reference_customer_trx_line_id   :=
            p_obj.reference_customer_trx_line_id;
        lr_new.split_by                         := p_obj.split_by;
        lr_new.line_set_id                      := p_obj.line_set_id;
        lr_new.service_txn_reason_code          :=
            p_obj.service_txn_reason_code;
        lr_new.service_txn_comments             := p_obj.service_txn_comments;
        lr_new.service_duration                 := p_obj.service_duration;
        lr_new.service_start_date               := p_obj.service_start_date;
        lr_new.service_end_date                 := p_obj.service_end_date;
        lr_new.service_coterminate_flag         :=
            p_obj.service_coterminate_flag;
        lr_new.unit_list_percent                := p_obj.unit_list_percent;
        lr_new.unit_selling_percent             := p_obj.unit_selling_percent;
        lr_new.unit_percent_base_price          :=
            p_obj.unit_percent_base_price;
        lr_new.service_number                   := p_obj.service_number;
        lr_new.service_period                   := p_obj.service_period;
        lr_new.shippable_flag                   := p_obj.shippable_flag;
        lr_new.model_remnant_flag               := p_obj.model_remnant_flag;
        lr_new.re_source_flag                   := p_obj.re_source_flag;
        lr_new.flow_status_code                 := p_obj.flow_status_code;
        lr_new.tp_context                       := p_obj.tp_context;
        lr_new.tp_attribute1                    := p_obj.tp_attribute1;
        lr_new.tp_attribute2                    := p_obj.tp_attribute2;
        lr_new.tp_attribute3                    := p_obj.tp_attribute3;
        lr_new.tp_attribute4                    := p_obj.tp_attribute4;
        lr_new.tp_attribute5                    := p_obj.tp_attribute5;
        lr_new.tp_attribute6                    := p_obj.tp_attribute6;
        lr_new.tp_attribute7                    := p_obj.tp_attribute7;
        lr_new.tp_attribute8                    := p_obj.tp_attribute8;
        lr_new.tp_attribute9                    := p_obj.tp_attribute9;
        lr_new.tp_attribute10                   := p_obj.tp_attribute10;
        lr_new.tp_attribute11                   := p_obj.tp_attribute11;
        lr_new.tp_attribute12                   := p_obj.tp_attribute12;
        lr_new.tp_attribute13                   := p_obj.tp_attribute13;
        lr_new.tp_attribute14                   := p_obj.tp_attribute14;
        lr_new.tp_attribute15                   := p_obj.tp_attribute15;
        lr_new.fulfillment_method_code          :=
            p_obj.fulfillment_method_code;
        lr_new.marketing_source_code_id         :=
            p_obj.marketing_source_code_id;
        lr_new.service_reference_type_code      :=
            p_obj.service_reference_type_code;
        lr_new.service_reference_line_id        :=
            p_obj.service_reference_line_id;
        lr_new.service_reference_system_id      :=
            p_obj.service_reference_system_id;
        lr_new.calculate_price_flag             := p_obj.calculate_price_flag;
        lr_new.upgraded_flag                    := p_obj.upgraded_flag;
        lr_new.revenue_amount                   := p_obj.revenue_amount;
        lr_new.fulfillment_date                 := p_obj.fulfillment_date;
        lr_new.preferred_grade                  := p_obj.preferred_grade;
        lr_new.ordered_quantity2                := p_obj.ordered_quantity2;
        lr_new.ordered_quantity_uom2            :=
            p_obj.ordered_quantity_uom2;
        lr_new.shipping_quantity2               := p_obj.shipping_quantity2;
        lr_new.cancelled_quantity2              := p_obj.cancelled_quantity2;
        lr_new.shipped_quantity2                := p_obj.shipped_quantity2;
        lr_new.shipping_quantity_uom2           :=
            p_obj.shipping_quantity_uom2;
        lr_new.fulfilled_quantity2              := p_obj.fulfilled_quantity2;
        lr_new.mfg_lead_time                    := p_obj.mfg_lead_time;
        lr_new.lock_control                     := p_obj.lock_control;
        lr_new.subinventory                     := p_obj.subinventory;
        lr_new.unit_list_price_per_pqty         :=
            p_obj.unit_list_price_per_pqty;
        lr_new.unit_selling_price_per_pqty      :=
            p_obj.unit_selling_price_per_pqty;
        lr_new.price_request_code               := p_obj.price_request_code;
        lr_new.original_inventory_item_id       :=
            p_obj.original_inventory_item_id;
        lr_new.original_ordered_item_id         :=
            p_obj.original_ordered_item_id;
        lr_new.original_ordered_item            :=
            p_obj.original_ordered_item;
        lr_new.original_item_identifier_type    :=
            p_obj.original_item_identifier_type;
        lr_new.item_substitution_type_code      :=
            p_obj.item_substitution_type_code;
        lr_new.override_atp_date_code           :=
            p_obj.override_atp_date_code;
        lr_new.late_demand_penalty_factor       :=
            p_obj.late_demand_penalty_factor;
        lr_new.accounting_rule_duration         :=
            p_obj.accounting_rule_duration;
        lr_new.attribute16                      := p_obj.attribute16;
        lr_new.attribute17                      := p_obj.attribute17;
        lr_new.attribute18                      := p_obj.attribute18;
        lr_new.attribute19                      := p_obj.attribute19;
        lr_new.attribute20                      := p_obj.attribute20;
        lr_new.user_item_description            :=
            p_obj.user_item_description;
        lr_new.unit_cost                        := p_obj.unit_cost;
        lr_new.item_relationship_type           :=
            p_obj.item_relationship_type;
        lr_new.blanket_line_number              := p_obj.blanket_line_number;
        lr_new.blanket_number                   := p_obj.blanket_number;
        lr_new.blanket_version_number           :=
            p_obj.blanket_version_number;
        lr_new.sales_document_type_code         :=
            p_obj.sales_document_type_code;
        lr_new.firm_demand_flag                 := p_obj.firm_demand_flag;
        lr_new.earliest_ship_date               := p_obj.earliest_ship_date;
        lr_new.transaction_phase_code           :=
            p_obj.transaction_phase_code;
        lr_new.source_document_version_number   :=
            p_obj.source_document_version_number;
        lr_new.payment_type_code                := p_obj.payment_type_code;
        lr_new.minisite_id                      := p_obj.minisite_id;
        lr_new.end_customer_id                  := p_obj.end_customer_id;
        lr_new.end_customer_contact_id          :=
            p_obj.end_customer_contact_id;
        lr_new.end_customer_site_use_id         :=
            p_obj.end_customer_site_use_id;
        lr_new.ib_owner                         := p_obj.ib_owner;
        lr_new.ib_current_location              := p_obj.ib_current_location;
        lr_new.ib_installed_at_location         :=
            p_obj.ib_installed_at_location;
        lr_new.retrobill_request_id             := p_obj.retrobill_request_id;
        lr_new.original_list_price              := p_obj.original_list_price;
        lr_new.service_credit_eligible_code     :=
            p_obj.service_credit_eligible_code;
        lr_new.order_firmed_date                := p_obj.order_firmed_date;
        lr_new.actual_fulfillment_date          :=
            p_obj.actual_fulfillment_date;
        lr_new.charge_periodicity_code          :=
            p_obj.charge_periodicity_code;
        lr_new.contingency_id                   := p_obj.contingency_id;
        lr_new.revrec_event_code                := p_obj.revrec_event_code;
        lr_new.revrec_expiration_days           :=
            p_obj.revrec_expiration_days;
        lr_new.accepted_quantity                := p_obj.accepted_quantity;
        lr_new.accepted_by                      := p_obj.accepted_by;
        lr_new.revrec_comments                  := p_obj.revrec_comments;
        lr_new.revrec_reference_document        :=
            p_obj.revrec_reference_document;
        lr_new.revrec_signature                 := p_obj.revrec_signature;
        lr_new.revrec_signature_date            :=
            p_obj.revrec_signature_date;
        lr_new.revrec_implicit_flag             := p_obj.revrec_implicit_flag;
        lr_new.bypass_sch_flag                  := p_obj.bypass_sch_flag;
        lr_new.pre_exploded_flag                := p_obj.pre_exploded_flag;
        lr_new.inst_id                          := p_obj.inst_id;
        lr_new.tax_line_value                   := p_obj.tax_line_value;
        lr_new.service_bill_profile_id          :=
            p_obj.service_bill_profile_id;
        lr_new.service_cov_template_id          :=
            p_obj.service_cov_template_id;
        lr_new.service_subs_template_id         :=
            p_obj.service_subs_template_id;
        lr_new.service_bill_option_code         :=
            p_obj.service_bill_option_code;
        lr_new.service_first_period_amount      :=
            p_obj.service_first_period_amount;
        lr_new.service_first_period_enddate     :=
            p_obj.service_first_period_enddate;
        lr_new.subscription_enable_flag         :=
            p_obj.subscription_enable_flag;
        lr_new.fulfillment_base                 := p_obj.fulfillment_base;
        lr_new.container_number                 := p_obj.container_number;
        lr_new.equipment_id                     := p_obj.equipment_id;
        RETURN lr_new;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Exception in oola_obj_to_rec_fnc: ' || SQLERRM, 1);
            RETURN NULL;
    END oola_obj_to_rec_fnc;
END xxd_ont_order_utils_pkg;
/
