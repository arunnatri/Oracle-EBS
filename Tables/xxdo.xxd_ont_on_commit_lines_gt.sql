--
-- XXD_ONT_ON_COMMIT_LINES_GT  (Table) 
--
CREATE GLOBAL TEMPORARY TABLE XXDO.XXD_ONT_ON_COMMIT_LINES_GT
(
  COMMITSCN  NUMBER
)
ON COMMIT DELETE ROWS
NOCACHE
/


--
-- XXD_ONT_ON_COMMIT_LINES_GT_TRG  (Trigger) 
--
--  Dependencies: 
--   XXD_ONT_ON_COMMIT_LINES_GT (Table)
--
CREATE OR REPLACE TRIGGER APPS.XXD_ONT_ON_COMMIT_LINES_GT_TRG 
  for update on xxdo.xxd_ont_on_commit_lines_gt
compound trigger
  /****************************************************************************************
  * Package      : XXD_ONT_ON_COMMIT_LINES_GT_TRG
  * Design       : This Trigger will initiate the CallOff Process for BULKs
  * Notes        :
  * Modification :
  -- ======================================================================================
  -- Date         Version#   Name                    Comments
  -- ======================================================================================
  -- 05-Mar-2020  1.0        Deckers                 Initial Version
  -- 18-Aug-2021  1.1        Deckers                 Updated for CCR0009550
  -- 31-Aug-2021  1.2        Deckers                 Updated for CCR0009567
  -- 13-Oct-2021  1.3        Deckers                 Updated for CCR0009654
  -- 14-Oct-2021  1.4        Deckers                 Updated for CCR0009669
  ******************************************************************************************/  
--  
  before statement is
  lc_error_message varchar2 (4000);
  ln_line_id number;
  -- Start changes for CCR0009567
  ln_user_id number;
  ln_resp_id number;
  ln_resp_appl_id number;
  -- End changes for CCR0009567
  -- Start changes for CCR0009550
  procedure msg (pc_msg in varchar2)
  as
  begin
    execute immediate 'begin xxd_debug_tools_pkg.msg(pc_msg => :msg, pc_origin => :origin); exception when others then null; end;' using in pc_msg, in 'Local Delegated Debug';
  end msg;
  -- End changes for CCR0009550
  begin
    msg ('In On-Commit Trigger - Start');
    -- Start changes for CCR0009550
    for rec in (select * from xxdo.xxd_ont_consum_parameters_gt)
    loop
      msg (rec.parameter_name || '=' || rec.parameter_value);
      if rec.parameter_name = 'xxd_ont_bulk_calloff_pkg.gc_no_unconsumption' then 
        msg ('Setting No Consumption Flag');
        xxd_ont_bulk_calloff_pkg.gc_no_unconsumption := rec.parameter_value;
      elsif rec.parameter_name = 'xxd_ont_order_utils_pkg.gc_skip_neg_unconsumption' then 
        msg ('Setting Skip Negative Consumption Flag');
        xxd_ont_order_utils_pkg.gc_skip_neg_unconsumption := rec.parameter_value;
      -- Start changes for CCR0009567
      elsif rec.parameter_name = 'apps_init' then
        msg ('Setting Apps Init Variables');
        ln_user_id := nvl (regexp_substr (rec.parameter_value, '[^#]+', 1, 1), -1);
        ln_resp_id := nvl (regexp_substr (rec.parameter_value, '[^#]+', 1, 2), -1);
        ln_resp_appl_id := nvl (regexp_substr (rec.parameter_value, '[^#]+', 1, 3), -1);
        --fnd_global.apps_initialize (user_id => ln_user_id, resp_id => ln_resp_id, resp_appl_id => ln_resp_appl_id); -- Commented for CCR0009654
      -- End changes for CCR0009567
      else
        fnd_profile.put (rec.parameter_name, rec.parameter_value);
      end if;
    end loop;
    -- End changes for CCR0009550
    xxd_ont_bulk_calloff_pkg.gc_commiting_flag := 'Y';
    for ln_idx in (with base as (
                   select line_id, inventory_item_id, min(idx) first_idx, max(idx) last_idx from xxdo.xxd_ont_consumption_gt group by line_id, inventory_item_id
                   order by inventory_item_id, line_id)
                   select gt_new.pr_new_obj, gt_old.pr_old_obj, decode (gt_new.operation, 'FORCE', 'FORCE', 'UNUSED') operation
                   from base b, xxdo.xxd_ont_consumption_gt gt_new, xxdo.xxd_ont_consumption_gt gt_old
                   where gt_new.idx (+) = b.last_idx
                   and gt_new.line_id (+) = b.line_id
                   and gt_new.inventory_item_id (+) = b.inventory_item_id
                   and gt_old.idx (+) = b.first_idx
                   and gt_old.line_id (+) = b.line_id
                   and gt_old.inventory_item_id (+) = b.inventory_item_id)
    loop
      ln_line_id := ln_idx.pr_new_obj.line_id;
      execute immediate 'begin xxd_ont_bulk_calloff_pkg.collect_lines (:act, :n, :o); exception when others then raise; end;' using in ln_idx.operation, in ln_idx.pr_new_obj, in ln_idx.pr_old_obj;
      msg ('In On-Commit Trigger - Collect Lines for Line ID: '||ln_line_id);
    end loop;
    msg ('In On-Commit Trigger - Collect Lines Completed');
    execute immediate 'begin xxd_ont_bulk_calloff_pkg.lock_lines; exception when others then raise; end;';
    msg ('In On-Commit Trigger - Lock Lines Completed');
    for ln_idx in (with base as (
                   select line_id, inventory_item_id, min(idx) first_idx, max(idx) last_idx from xxdo.xxd_ont_consumption_gt group by line_id, inventory_item_id
                   order by inventory_item_id, line_id)
                   select gt_new.pr_new_obj, gt_old.pr_old_obj, decode (gt_new.operation, 'FORCE', 'FORCE', 'UNUSED') operation
                   from base b, xxdo.xxd_ont_consumption_gt gt_new, xxdo.xxd_ont_consumption_gt gt_old
                   where gt_new.idx (+) = b.last_idx
                   and gt_new.line_id (+) = b.line_id
                   and gt_new.inventory_item_id (+) = b.inventory_item_id
                   and gt_old.idx (+) = b.first_idx
                   and gt_old.line_id (+) = b.line_id
                   and gt_old.inventory_item_id (+) = b.inventory_item_id)
    loop
      ln_line_id := ln_idx.pr_new_obj.line_id;
      execute immediate 'begin xxd_ont_bulk_calloff_pkg.process_order_line_change(:act, :n, :o); exception when others then raise; end;' using in ln_idx.operation, in ln_idx.pr_new_obj, in ln_idx.pr_old_obj;
      msg ('In On-Commit Trigger - Process Order Change for Line ID: '||ln_line_id);
    end loop;
    msg ('In On-Commit Trigger - Process Order Change Completed');
    xxd_ont_bulk_calloff_pkg.gc_commiting_flag := 'N';
    delete from xxdo.xxd_ont_consumption_gt;
  exception when others then
    msg ('before statement exception='|| substr (sqlerrm, 1, 1000)); 
    begin
      lc_error_message := substr ('Something went wrong in the consumption process in AUDSID: '|| sys_context('USERENV', 'SESSIONID'), 1, 4000) || '. '|| substr (sqlerrm, 1, 1000);
      insert into xxdo.xxd_ont_bulk_orders_t (bulk_id, status,  calloff_line_id, error_message, creation_date) values (xxdo.xxd_ont_bulk_orders_s.nextval, 'E', ln_line_id, lc_error_message, sysdate); -- Added CREATION_DATE for CCR0009669
    exception when others then
      null;
    end;
  end before statement;
--  
end xxd_ont_on_commit_lines_gt_trg;
/
