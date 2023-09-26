/*
  Usage:
  
    Determine employee has an employee type:
      if (new GenericUserUtil().hasEmployeeType("employee-type")) {
        //deny or grant access
      }
      
    Determine if employee is in a company:
      if (new GenericUserUtil().isInCompany("company-sys-id")) {
        //deny or grant access
      }
      
    Determine if employee is in a company:
      if (new GenericUserUtil().isInParentDepartment("department-sys-id")) {
        //deny or grant access
      }      
*/
var GenericUserUtil = Class.create();
GenericUserUtil.prototype = {
	//User GlideRecord Object
	userReference : null,
	
	//Constructor - instantiates User GlideRecord - thows GenericUserUtilNotFoundException on invalid sys_id
	initialize: function() {
		this.userReference = new GlideRecord('sys_user'); 
		if (!this.userReference.get(gs.getUserID())) throw 'GenericUserUtilNotFoundException';
  	},
	
	//hasEmployeeType - returns true if user has employee type <empType>, false if not
	hasEmployeeType : function(empType) {
		return (this.userReference.u_employee_type == empType) ? true : false;
	},
	
	//isInCompany - returns 
	isInCompany : function(companyId) {
		return (this.userReference.company == companyId) ? true : false;
	},
	
	//isInParentDepartment - returns true if the user's parent department has the sys_id <departmentId>, false if not, throws GenericUserUtilDepartmentNotDefinedException if no department is defined for user
	isInParentDepartment : function(departmentId) {
		var deptGr = new GlideRecord("cmn_department");
		if (!deptGr.get(this.userReference.department) && this.userReference.department.length > 0) throw 'GenericUserUtilDepartmentNotDefinedException';
		return (deptGr.parent == departmentId) ? true : false;
	},
	
	type: 'GenericUserUtil'
};