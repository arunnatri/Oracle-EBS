--
-- XXD_AP_GET_ACC_FOR_PREPAID_EXP  (Function) 
--
CREATE OR REPLACE FUNCTION APPS."XXD_AP_GET_ACC_FOR_PREPAID_EXP" (
   p_transaction_id   IN NUMBER,
   p_inv_dist_id	IN NUMBER)
   RETURN NUMBER
IS
   v_acctid   NUMBER := NULL;
   v_flag       VARCHAR2 (20) := 'N';
   v_acct		VARCHAR2(100)	:= NULL;
   v_par_flex_val	VARCHAR2(50) := NULL;    
BEGIN
   BEGIN
      SELECT 'Y', gcc.segment6
		INTO v_flag,v_acct
		FROM apps.ap_invoice_lines_all aila,
			 apps.ap_invoice_distributions_all aida,
			 apps.gl_code_combinations_kfv gcc
	   WHERE 1=1
		 AND aila.invoice_id = aida.invoice_id
		 AND aida.invoice_line_number = aila.line_number
     AND aila.line_type_lookup_code IN ('ITEM','TAX')
		 AND aila.deferred_acctg_flag = 'Y'
		 AND gcc.code_combination_id = aida.dist_code_combination_id
		 AND gcc.enabled_flag = 'Y'
		 AND aida.invoice_id = p_transaction_id
     AND aida.invoice_distribution_id = p_inv_dist_id;
   EXCEPTION
   WHEN OTHERS
   THEN
		v_flag := 'N';
   END;	
      
    IF v_flag = 'Y' and NVL(v_acct,-9999) <> -9999
    THEN
		BEGIN
			SELECT UNIQUE PARENT_FLEX_VALUE_LOW
			   INTO v_par_flex_val
			   FROM (SELECT ffv.flex_value ,
							ffv.parent_flex_value_low
					   FROM apps.fnd_flex_value_sets ffvs,
							apps.fnd_flex_values ffv
					  WHERE ffvs.flex_value_set_name = 'XXDO_AP_PREPAID_ACC_DVS'
						AND ffvs.flex_Value_Set_id     = ffv.flex_value_set_id)
			  WHERE FLEX_VALUE = v_acct
				AND ROWNUM = 1 ;
		EXCEPTION
		WHEN OTHERS
		THEN
			v_par_flex_val := '11601';
			NULL;
		END;
	ELSE
		v_par_flex_val := NULL;
	END IF;

	IF 	v_par_flex_val IS NOT NULL
	THEN
		BEGIN
		SELECT gcc.code_combination_id
		  INTO v_acctid
		  FROM gl_code_combinations_kfv gcc
	     WHERE gcc.segment6 = v_par_flex_val
		   AND gcc.enabled_flag = 'Y'
		   AND ROWNUM = 1;
		EXCEPTION
		WHEN OTHERS
		THEN
			v_acctid := NULL;
		END;
	END IF;
     
	RETURN v_acctid;

EXCEPTION
   WHEN OTHERS
   THEN
      v_acctid := NULL;
	  RETURN v_acctid;
	  
END XXD_AP_GET_ACC_FOR_PREPAID_EXP;
/
