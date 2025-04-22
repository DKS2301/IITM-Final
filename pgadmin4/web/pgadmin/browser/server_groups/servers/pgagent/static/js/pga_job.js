/////////////////////////////////////////////////////////////
//
// pgAdmin 4 - PostgreSQL Tools
//
// Copyright (C) 2013 - 2025, The pgAdmin Development Team
// This software is released under the PostgreSQL Licence
//
//////////////////////////////////////////////////////////////

import { getNodeAjaxOptions } from '../../../../../static/js/node_ajax';
import PgaJobSchema from './pga_job.ui';
import { getNodePgaJobStepSchema } from '../../steps/static/js/pga_jobstep.ui';
import getApiInstance from '../../../../../../static/js/api_instance';
import pgAdmin from 'sources/pgadmin';

define('pgadmin.node.pga_job', [
  'sources/gettext', 'sources/url_for', 'pgadmin.browser',
  'pgadmin.node.pga_jobstep', 'pgadmin.node.pga_schedule',
], function(gettext, url_for, pgBrowser) {

  if (!pgBrowser.Nodes['coll-pga_job']) {
    pgBrowser.Nodes['coll-pga_job'] =
      pgBrowser.Collection.extend({
        node: 'pga_job',
        label: gettext('pga_jobs'),
        type: 'coll-pga_job',
        columns: ['jobid', 'jobname', 'jobenabled', 'jlgstatus', 'jobnextrun', 'joblastrun', 'jobdesc'],
        hasStatistics: false,
        canDrop: true,
        canDropCascade: false,
      });
  }

  if (!pgBrowser.Nodes['pga_job']) {
    pgBrowser.Nodes['pga_job'] = pgBrowser.Node.extend({
      parent_type: 'server',
      type: 'pga_job',
      dialogHelp: url_for('help.static', {'filename': 'pgagent_jobs.html'}),
      hasSQL: true,
      hasDepends: false,
      hasStatistics: true,
      hasCollectiveStatistics: true,
      width: '80%',
      height: '80%',
      canDrop: true,
      label: gettext('pgAgent Job'),
      node_image: function() {
        return 'icon-pga_job';
      },
      Init: function() {
        /* Avoid mulitple registration of menus */
        if (this.initialized)
          return;

        this.initialized = true;

        pgBrowser.add_menus([{
          name: 'create_pga_job_on_coll', node: 'coll-pga_job', module: this,
          applies: ['object', 'context'], callback: 'show_obj_properties',
          category: 'create', priority: 4, label: gettext('pgAgent Job...'),
          data: {action: 'create'},
        },{
          name: 'create_pga_job', node: 'pga_job', module: this,
          applies: ['object', 'context'], callback: 'show_obj_properties',
          category: 'create', priority: 4, label: gettext('pgAgent Job...'),
          data: {action: 'create'},
        }, {
          name: 'run_now_pga_job', node: 'pga_job', module: this,
          applies: ['object', 'context'], callback: 'run_pga_job_now',
          priority: 4, label: gettext('Run now'), data: {action: 'create'},
        }, {
          name: 'job_audit_log', node: 'coll-pga_job', module: this,
          applies: ['object', 'context'], callback: 'show_job_audit_log',
          priority: 5, label: gettext('Job Audit Log (All)'), icon: 'fa fa-history',
        }, {
          name: 'job_audit_log_create', node: 'coll-pga_job', module: this,
          applies: ['object', 'context'], callback: 'show_job_audit_log_create',
          priority: 5, label: gettext('Job Audit Log (Create)'), icon: 'fa fa-plus',
        }, {
          name: 'job_audit_log_modify', node: 'coll-pga_job', module: this,
          applies: ['object', 'context'], callback: 'show_job_audit_log_modify',
          priority: 5, label: gettext('Job Audit Log (Modify)'), icon: 'fa fa-edit',
        }, {
          name: 'job_audit_log_delete', node: 'coll-pga_job', module: this,
          applies: ['object', 'context'], callback: 'show_job_audit_log_delete',
          priority: 5, label: gettext('Job Audit Log (Delete)'), icon: 'fa fa-trash',
        }, {
          name: 'job_audit_log_execute', node: 'coll-pga_job', module: this,
          applies: ['object', 'context'], callback: 'show_job_audit_log_execute',
          priority: 5, label: gettext('Job Audit Log (Execute)'), icon: 'fa fa-play',
        }]);
      },

      getSchema: function(treeNodeInfo, itemNodeData) {
        return new PgaJobSchema(
          {
            jobjclid: ()=>getNodeAjaxOptions('classes', this, treeNodeInfo, itemNodeData, {
              cacheLevel: 'server',
              cacheNode: 'server'
            }),
            jobs: ()=>getNodeAjaxOptions('jobs', this, treeNodeInfo, itemNodeData, {
              cacheLevel: 'server',
              cacheNode: 'server',
              urlWithId: true,
              useCache: false
            })
          },
          () => getNodePgaJobStepSchema(treeNodeInfo, itemNodeData),
        );
      },

      /* Run pgagent job now */
      run_pga_job_now: function(args) {
        let input = args || {},
          obj = this,
          t = pgBrowser.tree,
          i = input.item || t.selected(),
          d = i  ? t.itemData(i) : undefined;

        if (d) {
          getApiInstance().put(
            obj.generate_url(i, 'run_now', d, true),
          ).then(({data: res})=> {
            pgAdmin.Browser.notifier.success(res.info);
            t.unload(i);
          }).catch(function(error) {
            pgAdmin.Browser.notifier.pgRespErrorNotify(error);
            t.unload(i);
          });
        }

        return false;
      },
      /* Common function for all Job Audit Log operations */
      _copy_job_audit_log_query: function(args, operation) {
        let input = args || {},
          t = pgBrowser.tree,
          i = input.item || t.selected(),
          d = i ? t.itemData(i) : undefined;

        if (!d) {
          pgAdmin.Browser.notifier.error(gettext('No item selected.'));
          return false;
        }

        // Find the server node so we know what database to connect to
        let serverNode = i;
        let serverData = d;
        
        if (d._type !== 'server') {
          // Navigate up to find the server
          while (serverData && serverData._type !== 'server' && serverNode) {
            serverNode = t.parent(serverNode);
            if (serverNode) {
              serverData = t.itemData(serverNode);
            }
          }
        }

        if (!serverNode || !serverData || serverData._type !== 'server') {
          pgAdmin.Browser.notifier.error(gettext('Could not find server node.'));
          return false;
        }

        try {
          // Build the query based on operation type
          let query = 'SELECT * FROM pgagent.pga_job_audit_log';
          
          // Add WHERE clause if operation is specified
          if (operation) {
            query += ' WHERE operation_type = ' + '\''+operation + '\'';
          }
          
          // Add ORDER BY clause
          query += ' ORDER BY operation_time DESC;';
          
          // Create a temporary textarea to copy the query
          const tempTextArea = document.createElement('textarea');
          tempTextArea.value = query;
          document.body.appendChild(tempTextArea);
          tempTextArea.select();
          document.execCommand('copy');
          document.body.removeChild(tempTextArea);
          
          // Show success message with operation type
          let operationLabel = operation ? operation : 'All';
          pgAdmin.Browser.notifier.success(
            gettext('SQL query for ' + operationLabel + ' operations copied to clipboard. Paste into the query tool and execute.')
          );
          
          // Now open the query tool 
          pgAdmin.Browser.Node.callbacks.show_query_tool({}, serverNode);
          
        } catch (error) {
          pgAdmin.Browser.notifier.error(gettext('Error: ') + error.message);
        }
        
        return false;
      },

      /* Show Job Audit Log - All operations */
      show_job_audit_log: function(args) {
        return this._copy_job_audit_log_query(args, null);
      },
      
      /* Show Job Audit Log - Create operations */
      show_job_audit_log_create: function(args) {
        return this._copy_job_audit_log_query(args, 'CREATE');
      },
      
      /* Show Job Audit Log - Modify operations */
      show_job_audit_log_modify: function(args) {
        return this._copy_job_audit_log_query(args, 'MODIFY');
      },
      
      /* Show Job Audit Log - Delete operations */
      show_job_audit_log_delete: function(args) {
        return this._copy_job_audit_log_query(args, 'DELETE');
      },
      
      /* Show Job Audit Log - Execute operations */
      show_job_audit_log_execute: function(args) {
        return this._copy_job_audit_log_query(args, 'EXECUTE');
      },
      /* Refresh the jobs list after creating a new job */
      onSave: function(isNew, data) {
        let obj = this;
        return obj.nodeAjax('create', data, {}, function(res) {
          if (res.success) {
            // Refresh the jobs list by invalidating the cache
            let cacheNode = pgAdmin.Browser.Nodes['server'];
            if (cacheNode) {
              cacheNode.cache(obj.type + '#jobs', {}, 'server', null);
            }
          }
        });
      }
    });
  }

  return pgBrowser.Nodes['pga_job'];
});
