REPORT z_ecc_to_s4_extraction.
TYPES: BEGIN OF ty_ecc_vendor,
         lifnr TYPE c LENGTH 10,  
         name1 TYPE c LENGTH 35,  
         land1 TYPE c LENGTH 3,   
         loekz TYPE c LENGTH 1,   
       END OF ty_ecc_vendor.
DATA: lt_ecc_staging TYPE TABLE OF ty_ecc_vendor,
      lv_rfc_dest    TYPE rfcdest VALUE 'ECC_PROD_CLNT100',
      lv_cursor      TYPE cursor.
START-OF-SELECTION.
    OPEN CURSOR lv_cursor FOR
    SELECT lifnr, name1, land1, loekz
      FROM lfa1 CONNECTION (lv_rfc_dest).
DO.
    FETCH NEXT CURSOR lv_cursor
      INTO TABLE lt_ecc_staging
      PACKAGE SIZE 5000.
IF sy-subrc <> 0.
      CLOSE CURSOR lv_cursor.
      EXIT; 
    ENDIF.
    INSERT zext_cust_stage FROM TABLE lt_ecc_staging.
    COMMIT WORK.
    CLEAR lt_ecc_staging.
  ENDDO.
WRITE: / 'Taking Phase Complete: All raw ECC records pushed to Staging Area.'.
METHOD filter_unwanted_records.
  FIELD-SYMBOLS: <fs_stage> TYPE zext_cust_stage.
  DATA: ls_clean TYPE zext_cust_stage.
LOOP AT it_staging_data ASSIGNING <fs_stage>.
        IF <fs_stage>-loekz = 'X'.
      CONTINUE; 
    ENDIF.
    IF <fs_stage>-lifnr IS INITIAL.
      CONTINUE; 
    ENDIF.
    MOVE-CORRESPONDING <fs_stage> TO ls_clean.
    APPEND ls_clean TO et_cleansed_data.
    CLEAR ls_clean.
     ENDLOOP.
ENDMETHOD.
METHOD transform_and_recorrect.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = is_cleansed_record-lifnr
    IMPORTING
      output = es_s4_target_structure-vendor_no.
  SELECT SINGLE land1 
    FROM t005 
    INTO es_s4_target_structure-country_iso
    WHERE land1 = is_cleansed_record-land1.
    IF sy-subrc <> 0.
        es_s4_target_structure-country_iso = 'IN'. 
  ENDIF.
  es_s4_target_structure-vendor_name = is_cleansed_record-name1.
ENDMETHOD.
METHOD load_and_transfer_s4.
   DATA: ls_target      TYPE zext_s4_vendor_struct,
        ls_bapi_data   TYPE bapicsupplier,
        lt_return      TYPE TABLE OF bapiret2,
        lo_sys_error   TYPE REF TO cx_sy_conversion_data_error,
        lv_err_msg     TYPE string.
LOOP AT it_transformed_data INTO ls_target.
    TRY.
        ls_bapi_data-supplier_no   = ls_target-vendor_no.
        ls_bapi_data-supplier_name = ls_target-vendor_name.
        ls_bapi_data-country       = ls_target-country_iso.
        CALL FUNCTION 'BAPI_BUSINESS_PARTNER_CREATE'
          STARTING NEW TASK 'MIG_JOB'
          DESTINATION IN GROUP 'MIGRATION_SERVER_POOL'
          EXPORTING
            is_supplier_data = ls_bapi_data
          TABLES
            return           = lt_return.
        IF line_exists( lt_return[ type = 'E' ] ) OR line_exists( lt_return[ type = 'A' ] ).
          ROLLBACK WORK. 
          INSERT INTO zext_err_log VALUES ( vendor_no = ls_target-vendor_no 
                                            err_type  = 'VALIDATION_FAIL' ).
        ELSE.
          COMMIT WORK. 
        ENDIF.
        CATCH cx_sy_conversion_data_error INTO lo_sys_error.
        ROLLBACK WORK. 
        lv_err_msg = lo_sys_error->get_text( ).
        PERFORM log_system_crash USING ls_target-vendor_no lv_err_msg.
        CONTINUE; 
    ENDTRY.
  ENDLOOP.
ENDMETHOD.
