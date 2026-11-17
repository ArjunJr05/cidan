class ConditionNode {
  final String field;
  final String operator;
  final dynamic value;
  final String valueType;
  final String? unit;

  const ConditionNode({
    required this.field,
    required this.operator,
    required this.value,
    this.valueType = 'numeric',
    this.unit,
  });

  factory ConditionNode.fromJson(Map<String, dynamic> json) {
    return ConditionNode(
      field: json['field'] as String? ?? '',
      operator: json['operator'] as String? ?? 'eq',
      value: json['value'],
      valueType: json['value_type'] as String? ?? 'numeric',
      unit: json['unit'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'field': field,
      'operator': operator,
      'value': value,
      'value_type': valueType,
      if (unit != null) 'unit': unit,
    };
  }
}

class ConditionTree {
  final String operator;
  final List<dynamic> conditions; // ConditionNode or ConditionTree

  const ConditionTree({
    this.operator = 'AND',
    this.conditions = const [],
  });

  factory ConditionTree.fromJson(Map<String, dynamic> json) {
    final rawList = json['conditions'] as List<dynamic>? ?? [];
    final parsedConditions = rawList.map((item) {
      if (item is Map<String, dynamic>) {
        if (item.containsKey('conditions')) {
          return ConditionTree.fromJson(item);
        } else {
          return ConditionNode.fromJson(item);
        }
      }
      return item;
    }).toList();

    return ConditionTree(
      operator: json['operator'] as String? ?? 'AND',
      conditions: parsedConditions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'operator': operator,
      'conditions': conditions.map((c) {
        if (c is ConditionNode) return c.toJson();
        if (c is ConditionTree) return c.toJson();
        return c;
      }).toList(),
    };
  }

  List<ConditionNode> get flattenLeaves {
    final leaves = <ConditionNode>[];
    for (final c in conditions) {
      if (c is ConditionNode) {
        leaves.add(c);
      } else if (c is ConditionTree) {
        leaves.addAll(c.flattenLeaves);
      }
    }
    return leaves;
  }
}

class ActionNode {
  final String actionType;
  final String target;
  final Map<String, dynamic> parameters;
  final int priority;
  final String failureBehavior;

  const ActionNode({
    this.actionType = 'FLAG_REVIEW',
    this.target = 'transaction',
    this.parameters = const {},
    this.priority = 1,
    this.failureBehavior = 'FAIL_CLOSED',
  });

  factory ActionNode.fromJson(Map<String, dynamic> json) {
    return ActionNode(
      actionType: json['action_type'] as String? ?? 'FLAG_REVIEW',
      target: json['target'] as String? ?? 'transaction',
      parameters: json['parameters'] is Map<String, dynamic>
          ? json['parameters'] as Map<String, dynamic>
          : {},
      priority: (json['priority'] as num?)?.toInt() ?? 1,
      failureBehavior: json['failure_behavior'] as String? ?? 'FAIL_CLOSED',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action_type': actionType,
      'target': target,
      'parameters': parameters,
      'priority': priority,
      'failure_behavior': failureBehavior,
    };
  }
}

class RuleIR {
  final String? id;
  final String? bankId;
  final String ruleId;
  final String ruleName;
  final String description;
  final String category;
  final String sourceType;
  final String? sourceId;
  final int version;
  final bool isActive;
  final String? effectiveDate;
  final String? expiryDate;
  final ConditionTree conditionTree;
  final List<ActionNode> actions;
  final Map<String, dynamic> parameters;
  final List<String> dependencies;
  final Map<String, dynamic> traceability;
  final String? rawContent;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const RuleIR({
    this.id,
    this.bankId,
    required this.ruleId,
    required this.ruleName,
    this.description = '',
    this.category = 'GENERAL',
    this.sourceType = 'EXISTING_DOCUMENT',
    this.sourceId,
    this.version = 1,
    this.isActive = true,
    this.effectiveDate,
    this.expiryDate,
    required this.conditionTree,
    this.actions = const [],
    this.parameters = const {},
    this.dependencies = const [],
    this.traceability = const {},
    this.rawContent,
    this.createdAt,
    this.updatedAt,
  });

  factory RuleIR.fromJson(Map<String, dynamic> json) {
    final rawTree = json['condition_tree'];
    final conditionTree = rawTree is Map<String, dynamic>
        ? ConditionTree.fromJson(rawTree)
        : const ConditionTree();

    final rawActions = json['actions'] as List<dynamic>? ?? [];
    final actions = rawActions
        .whereType<Map<String, dynamic>>()
        .map((a) => ActionNode.fromJson(a))
        .toList();

    return RuleIR(
      id: json['id'] as String?,
      bankId: json['bank_id'] as String?,
      ruleId: json['rule_id'] as String? ?? 'RULE-UNKNOWN',
      ruleName: json['rule_name'] as String? ?? 'Untitled Rule',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'GENERAL',
      sourceType: json['source_type'] as String? ?? 'EXISTING_DOCUMENT',
      sourceId: json['source_id'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 1,
      isActive: json['is_active'] as bool? ?? true,
      effectiveDate: json['effective_date'] as String?,
      expiryDate: json['expiry_date'] as String?,
      conditionTree: conditionTree,
      actions: actions,
      parameters: json['parameters'] is Map<String, dynamic>
          ? json['parameters'] as Map<String, dynamic>
          : {},
      dependencies: (json['dependencies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      traceability: json['traceability'] is Map<String, dynamic>
          ? json['traceability'] as Map<String, dynamic>
          : {},
      rawContent: json['raw_content'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (bankId != null) 'bank_id': bankId,
      'rule_id': ruleId,
      'rule_name': ruleName,
      'description': description,
      'category': category,
      'source_type': sourceType,
      if (sourceId != null) 'source_id': sourceId,
      'version': version,
      'is_active': isActive,
      if (effectiveDate != null) 'effective_date': effectiveDate,
      if (expiryDate != null) 'expiry_date': expiryDate,
      'condition_tree': conditionTree.toJson(),
      'actions': actions.map((a) => a.toJson()).toList(),
      'parameters': parameters,
      'dependencies': dependencies,
      'traceability': traceability,
      if (rawContent != null) 'raw_content': rawContent,
    };
  }
}
