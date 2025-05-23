##########################################################################
#
# pgAdmin 4 - PostgreSQL Tools
#
# Copyright (C) 2013 - 2025, The pgAdmin Development Team
# This software is released under the PostgreSQL Licence
#
##########################################################################

"""A blueprint module implementing the dashboard frame."""
import math
import re

from flask import render_template, Response, g, request
from flask_babel import gettext
from pgadmin.user_login_check import pga_login_required
import json
from pgadmin.utils import PgAdminModule
from pgadmin.utils.ajax import make_response as ajax_response,\
    internal_server_error, make_json_response, precondition_required
from pgadmin.utils.driver import get_driver
from pgadmin.utils.preferences import Preferences
from pgadmin.utils.constants import PREF_LABEL_DISPLAY, MIMETYPE_APP_JS, \
    PREF_LABEL_REFRESH_RATES, ERROR_SERVER_ID_NOT_SPECIFIED

from .precondition import check_precondition
from .pgd_replication import blueprint as pgd_replication
from config import PG_DEFAULT_DRIVER, ON_DEMAND_LOG_COUNT

MODULE_NAME = 'dashboard'


class DashboardModule(PgAdminModule):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

    def get_own_menuitems(self):
        return {}

    def register_preferences(self):
        """
        register_preferences
        Register preferences for this module.
        """
        help_string = gettext('The number of seconds between graph samples.')

        # Register options for Dashboards
        self.dashboard_preference = Preferences(
            'dashboards', gettext('Dashboards')
        )

        self.session_stats_refresh = self.dashboard_preference.register(
            'dashboards', 'session_stats_refresh',
            gettext("Session statistics refresh rate"), 'integer',
            5, min_val=1, max_val=999999,
            category_label=PREF_LABEL_REFRESH_RATES,
            help_str=help_string
        )

        self.tps_stats_refresh = self.dashboard_preference.register(
            'dashboards', 'tps_stats_refresh',
            gettext("Transaction throughput refresh rate"), 'integer',
            5, min_val=1, max_val=999999,
            category_label=PREF_LABEL_REFRESH_RATES,
            help_str=help_string
        )

        self.ti_stats_refresh = self.dashboard_preference.register(
            'dashboards', 'ti_stats_refresh',
            gettext("Tuples in refresh rate"), 'integer',
            5, min_val=1, max_val=999999,
            category_label=PREF_LABEL_REFRESH_RATES,
            help_str=help_string
        )

        self.to_stats_refresh = self.dashboard_preference.register(
            'dashboards', 'to_stats_refresh',
            gettext("Tuples out refresh rate"), 'integer',
            5, min_val=1, max_val=999999,
            category_label=PREF_LABEL_REFRESH_RATES,
            help_str=help_string
        )

        self.bio_stats_refresh = self.dashboard_preference.register(
            'dashboards', 'bio_stats_refresh',
            gettext("Block I/O statistics refresh rate"), 'integer',
            5, min_val=1, max_val=999999,
            category_label=PREF_LABEL_REFRESH_RATES,
            help_str=help_string
        )

        self.hpc_stats_refresh = self.dashboard_preference.register(
            'dashboards', 'hpc_stats_refresh',
            gettext("Handle & Process count statistics refresh rate"),
            'integer', 5, min_val=1, max_val=999999,
            category_label=PREF_LABEL_REFRESH_RATES,
            help_str=help_string
        )

        self.cpu_stats_refresh = self.dashboard_preference.register(
            'dashboards', 'cpu_stats_refresh',
            gettext(
                "Percentage of CPU time used by different process \
                modes statistics refresh rate"
            ), 'integer', 5, min_val=1, max_val=999999,
            category_label=PREF_LABEL_REFRESH_RATES,
            help_str=help_string
        )

        self.la_stats_refresh = self.dashboard_preference.register(
            'dashboards', 'la_stats_refresh',
            gettext("Average load statistics refresh rate"), 'integer',
            5, min_val=1, max_val=999999,
            category_label=PREF_LABEL_REFRESH_RATES,
            help_str=help_string
        )

        self.pcpu_stats_refresh = self.dashboard_preference.register(
            'dashboards', 'pcpu_stats_refresh',
            gettext("CPU usage per process statistics refresh rate"),
            'integer', 5, min_val=1, max_val=999999,
            category_label=PREF_LABEL_REFRESH_RATES,
            help_str=help_string
        )

        self.m_stats_refresh = self.dashboard_preference.register(
            'dashboards', 'm_stats_refresh',
            gettext("Memory usage statistics refresh rate"), 'integer',
            5, min_val=1, max_val=999999,
            category_label=PREF_LABEL_REFRESH_RATES,
            help_str=help_string
        )

        self.sm_stats_refresh = self.dashboard_preference.register(
            'dashboards', 'sm_stats_refresh',
            gettext("Swap memory usage statistics refresh rate"), 'integer',
            5, min_val=1, max_val=999999,
            category_label=PREF_LABEL_REFRESH_RATES,
            help_str=help_string
        )

        self.pmu_stats_refresh = self.dashboard_preference.register(
            'dashboards', 'pmu_stats_refresh',
            gettext("Memory usage per process statistics refresh rate"),
            'integer', 5, min_val=1, max_val=999999,
            category_label=PREF_LABEL_REFRESH_RATES,
            help_str=help_string
        )

        self.io_stats_refresh = self.dashboard_preference.register(
            'dashboards', 'io_stats_refresh',
            gettext("I/O analysis statistics refresh rate"), 'integer',
            5, min_val=1, max_val=999999,
            category_label=PREF_LABEL_REFRESH_RATES,
            help_str=help_string
        )

        self.display_graphs = self.dashboard_preference.register(
            'display', 'show_graphs',
            gettext("Show activity?"), 'boolean', True,
            category_label=PREF_LABEL_DISPLAY,
            help_str=gettext('If set to True, activity '
                             'will be displayed on dashboards.')
        )

        self.display_server_activity = self.dashboard_preference.register(
            'display', 'show_activity',
            gettext("Show state?"), 'boolean', True,
            category_label=PREF_LABEL_DISPLAY,
            help_str=gettext('If set to True, state tables '
                             'will be displayed on dashboards.')
        )

        self.long_running_query_threshold = self.dashboard_preference.register(
            'display', 'long_running_query_threshold',
            gettext('Long running query thresholds'), 'threshold',
            '2|5', category_label=PREF_LABEL_DISPLAY,
            help_str=gettext('Set the warning and alert threshold value to '
                             'highlight the long-running queries on the '
                             'dashboard.')
        )

        # Register options for Graphs
        self.graphs_preference = Preferences(
            'graphs', gettext('Graphs')
        )

        self.graph_data_points = self.graphs_preference.register(
            'graphs', 'graph_data_points',
            gettext("Show graph data points?"), 'boolean', False,
            category_label=PREF_LABEL_DISPLAY,
            help_str=gettext('If set to True, data points will be '
                             'visible on graph lines.')
        )

        self.use_diff_point_style = self.graphs_preference.register(
            'graphs', 'use_diff_point_style',
            gettext("Use different data point styles?"), 'boolean', False,
            category_label=PREF_LABEL_DISPLAY,
            help_str=gettext('If set to True, data points will be visible '
                             'in a different style on each graph lines.')
        )

        self.graph_mouse_track = self.graphs_preference.register(
            'graphs', 'graph_mouse_track',
            gettext("Show mouse hover tooltip?"), 'boolean', True,
            category_label=PREF_LABEL_DISPLAY,
            help_str=gettext('If set to True, tooltip will appear on mouse '
                             'hover on the graph lines giving the data point '
                             'details')
        )

        self.graph_line_border_width = self.graphs_preference.register(
            'graphs', 'graph_line_border_width',
            gettext("Chart line width"), 'integer',
            1, min_val=1, max_val=10,
            category_label=PREF_LABEL_DISPLAY,
            help_str=gettext('Set the width of the lines on the line chart.')
        )

        pgd_replication.register_preferences(self)

    def get_exposed_url_endpoints(self):
        """
        Returns:
            list: a list of url endpoints exposed to the client.
        """
        return [
            'dashboard.index', 'dashboard.get_by_sever_id',
            'dashboard.get_by_database_id',
            'dashboard.dashboard_stats',
            'dashboard.dashboard_stats_sid',
            'dashboard.dashboard_stats_did',
            'dashboard.activity',
            'dashboard.get_activity_by_server_id',
            'dashboard.get_activity_by_database_id',
            'dashboard.locks',
            'dashboard.get_locks_by_server_id',
            'dashboard.get_locks_by_database_id',
            'dashboard.prepared',
            'dashboard.get_prepared_by_server_id',
            'dashboard.get_prepared_by_database_id',
            'dashboard.config',
            'dashboard.log_formats',
            'dashboard.logs',
            'dashboard.get_logs_by_server_id',
            'dashboard.check_system_statistics',
            'dashboard.check_system_statistics_sid',
            'dashboard.check_system_statistics_did',
            'dashboard.system_statistics',
            'dashboard.system_statistics_sid',
            'dashboard.system_statistics_did',
            'dashboard.replication_slots',
            'dashboard.replication_stats',
            'dashboard.job_monitor',
            'dashboard.run_job',
            'dashboard.job_log',
            'dashboard.audit_logs',
            'dashboard.job_names',
            'dashboard.job_dependency_graph',
        ] + pgd_replication.get_exposed_url_endpoints()


blueprint = DashboardModule(MODULE_NAME, __name__)
blueprint.register_blueprint(pgd_replication)


@blueprint.route("/dashboard.js")
@pga_login_required
def script():
    """render the required javascript"""
    return Response(
        response=render_template(
            "dashboard/js/dashboard.js",
            _=gettext
        ),
        status=200,
        mimetype=MIMETYPE_APP_JS
    )


@blueprint.route('/', endpoint='index')
@blueprint.route('/<int:sid>', endpoint='get_by_sever_id')
@blueprint.route('/<int:sid>/<int:did>', endpoint='get_by_database_id')
@pga_login_required
def index(sid=None, did=None):
    """
    Renders the welcome, server or database dashboard
    Args:
        sid: Server ID
        did: Database ID

    Returns: Welcome/Server/database dashboard

    """
    rates = {}

    # Get the server version
    if sid is not None:
        g.manager = get_driver(
            PG_DEFAULT_DRIVER).connection_manager(sid)
        g.conn = g.manager.connection()

        g.version = g.manager.version

        if not g.conn.connected():
            g.version = 0

    # Show the appropriate dashboard based on the identifiers passed to us
    if sid is None and did is None:
        return render_template('/dashboard/welcome_dashboard.html')
    if did is None:
        return render_template(
            '/dashboard/server_dashboard.html',
            sid=sid,
            rates=rates,
            version=g.version
        )
    else:
        return render_template(
            '/dashboard/database_dashboard.html',
            sid=sid,
            did=did,
            rates=rates,
            version=g.version
        )


def get_data(sid, did, template, check_long_running_query=False,
             only_data=False):
    """
    Generic function to get server stats based on an SQL template
    Args:
        sid: The server ID
        did: The database ID
        template: The SQL template name
        check_long_running_query:

    Returns:

    """
    # Allow no server ID to be specified (so we can generate a route in JS)
    # but throw an error if it's actually called.
    if not sid:
        return internal_server_error(errormsg=ERROR_SERVER_ID_NOT_SPECIFIED)

    sql = render_template(
        "/".join([g.template_path, template]), did=did
    )
    status, res = g.conn.execute_dict(sql)

    if not status:
        return internal_server_error(errormsg=res)

    # Check the long running query status and set the row type.
    if check_long_running_query:
        get_long_running_query_status(res['rows'])

    if only_data:
        return res['rows']

    return ajax_response(
        response=res['rows'],
        status=200
    )


def get_long_running_query_status(activities):
    """
    This function is used to check the long running query and set the
    row type to highlight the row color accordingly
    """
    dash_preference = Preferences.module('dashboards')
    long_running_query_threshold = \
        dash_preference.preference('long_running_query_threshold').get()

    if long_running_query_threshold is not None:
        long_running_query_threshold = long_running_query_threshold.split('|')

        warning_value = float(long_running_query_threshold[0]) \
            if long_running_query_threshold[0] != '' else math.inf
        alert_value = float(long_running_query_threshold[1]) \
            if long_running_query_threshold[1] != '' else math.inf

        for row in activities:
            row['row_type'] = None

            # We care for only those queries which are in active state and
            # have active_since parameter and not None
            if row['state'] == 'active' and 'active_since' in row and \
                    row['active_since'] is not None:
                active_since = float(row['active_since'])
                if active_since > warning_value:
                    row['row_type'] = 'warning'
                if active_since > alert_value:
                    row['row_type'] = 'alert'


@blueprint.route('/dashboard_stats',
                 endpoint='dashboard_stats')
@blueprint.route('/dashboard_stats/<int:sid>',
                 endpoint='dashboard_stats_sid')
@blueprint.route('/dashboard_stats/<int:sid>/<int:did>',
                 endpoint='dashboard_stats_did')
@pga_login_required
@check_precondition
def dashboard_stats(sid=None, did=None):
    resp_data = {}

    if request.args['chart_names'] != '':
        chart_names = request.args['chart_names'].split(',')

        if not sid:
            return internal_server_error(
                errormsg=ERROR_SERVER_ID_NOT_SPECIFIED)

        sql = render_template(
            "/".join([g.template_path, 'dashboard_stats.sql']), did=did,
            chart_names=chart_names,
        )
        _, res = g.conn.execute_dict(sql)

        for chart_row in res['rows']:
            resp_data[chart_row['chart_name']] = json.loads(
                chart_row['chart_data'])

    return ajax_response(
        response=resp_data,
        status=200
    )


@blueprint.route('/activity/', endpoint='activity')
@blueprint.route('/activity/<int:sid>', endpoint='get_activity_by_server_id')
@blueprint.route(
    '/activity/<int:sid>/<int:did>', endpoint='get_activity_by_database_id'
)
@pga_login_required
@check_precondition
def activity(sid=None, did=None):
    """
    This function returns server activity information
    :param sid: server id
    :return:
    """
    data = [{
        'activity': get_data(sid, did, 'activity.sql', True, True),
        'locks': get_data(sid, did, 'locks.sql', only_data=True),
        'prepared': get_data(sid, did, 'prepared.sql', only_data=True)
    }]
    return ajax_response(
        response=data,
        status=200
    )


@blueprint.route('/locks/', endpoint='locks')
@blueprint.route('/locks/<int:sid>', endpoint='get_locks_by_server_id')
@blueprint.route(
    '/locks/<int:sid>/<int:did>', endpoint='get_locks_by_database_id'
)
@pga_login_required
@check_precondition
def locks(sid=None, did=None):
    """
    This function returns server lock information
    :param sid: server id
    :return:
    """
    return get_data(sid, did, 'locks.sql')


@blueprint.route('/prepared/', endpoint='prepared')
@blueprint.route('/prepared/<int:sid>', endpoint='get_prepared_by_server_id')
@blueprint.route(
    '/prepared/<int:sid>/<int:did>', endpoint='get_prepared_by_database_id'
)
@pga_login_required
@check_precondition
def prepared(sid=None, did=None):
    """
    This function returns prepared XACT information
    :param sid: server id
    :return:
    """
    return get_data(sid, did, 'prepared.sql')


@blueprint.route('/config/<int:sid>', endpoint='config')
@pga_login_required
@check_precondition
def config(sid=None):
    """
    This function returns server config information
    :param sid: server id
    :return:
    """
    return get_data(sid, None, 'config.sql')


@blueprint.route('/log_formats', endpoint='log_formats')
@blueprint.route('/log_formats/<int:sid>', endpoint='log_formats')
@pga_login_required
@check_precondition
def log_formats(sid=None):
    if not sid:
        return internal_server_error(errormsg='Server ID not specified.')

    sql = render_template(
        "/".join([g.template_path, 'log_format.sql'])
    )
    status, _format = g.conn.execute_scalar(sql)

    if not status:
        return internal_server_error(errormsg=_format)

    return ajax_response(
        response=_format,
        status=200
    )


@blueprint.route('/logs/<log_format>/<disp_format>/<int:sid>', endpoint='logs')
@blueprint.route('/logs/<log_format>/<disp_format>/<int:sid>/<int:page>',
                 endpoint='get_logs_by_server_id')
@pga_login_required
@check_precondition
def logs(log_format=None, disp_format=None, sid=None, page=0):
    """
    This function returns server logs details
    """

    LOG_STATEMENTS = 'DEBUG:|STATEMENT:|LOG:|WARNING:|NOTICE:|INFO:' \
                     '|ERROR:|FATAL:|PANIC:'
    if not sid:
        return internal_server_error(
            errormsg=gettext('Server ID not specified.'))

    sql = render_template(
        "/".join([g.template_path, 'log_format.sql'])
    )
    status, _format = g.conn.execute_scalar(sql)

    # Check the requested format is available or not
    if log_format == 'C' and 'csvlog' in _format:
        log_format = 'csvlog'
    elif log_format == 'J' and 'jsonlog' in _format:
        log_format = 'jsonlog'
    else:
        log_format = ''

    sql = render_template(
        "/".join([g.template_path, 'log_stat.sql']),
        log_format=log_format, conn=g.conn
    )

    status, res = g.conn.execute_scalar(sql)
    if not status:
        return internal_server_error(errormsg=res)
    if not res or len(res) <= 0:
        return ajax_response(
            response={'logs_disabled': True},
            status=200
        )

    file_stat = json.loads(res[0])

    if file_stat <= 0:
        return ajax_response(
            response={'logs_disabled': True},
            status=200
        )

    _start = 0
    _end = ON_DEMAND_LOG_COUNT
    page = int(page)
    final_cols = []
    if page > 0:
        _start = page * int(ON_DEMAND_LOG_COUNT)
        _end = _start + int(ON_DEMAND_LOG_COUNT)

    if _start < file_stat:
        if disp_format == 'plain':
            _end = file_stat
        sql = render_template(
            "/".join([g.template_path, 'logs.sql']), st=_start, ed=_end,
            log_format=log_format, conn=g.conn
        )
        status, res = g.conn.execute_dict(sql)
        if not status:
            return internal_server_error(errormsg=res)

        final_res = res['rows'][0]['pg_read_file'].split('\n')
        # Json format
        if log_format == 'jsonlog':
            for f in final_res:
                try:
                    _tmp_log = json.loads(f)
                    final_cols.append(
                        {"error_severity": _tmp_log['error_severity'],
                         "timestamp": _tmp_log['timestamp'],
                         "message": _tmp_log['message']})
                except Exception:
                    pass

        # CSV format
        elif log_format == 'csvlog':
            for f in final_res:
                try:
                    _tmp_log = f.split(',')
                    final_cols.append({"error_severity": _tmp_log[11],
                                       "timestamp": _tmp_log[0],
                                       "message": _tmp_log[13]})
                except Exception:
                    pass

        else:
            _pattern = re.compile(LOG_STATEMENTS)
            for f in final_res:
                tmp = re.search(LOG_STATEMENTS, f)
                if not tmp or tmp.group((0)) == 'STATEMENT:':
                    last_val = final_cols.pop() if len(final_cols) > 0\
                        else {'message': ''}
                    last_val['message'] += f
                    final_cols.append(last_val)
                else:
                    _tmp = re.split(LOG_STATEMENTS, f)

                    final_cols.append({
                        "error_severity": tmp.group(0)[:len(tmp.group(0)) - 1],
                        "timestamp": _tmp[0],
                        "message": _tmp[1] if len(_tmp) > 1 else ''})

    if disp_format == 'plain':
        final_response = res['rows']
    else:
        final_response = final_cols

    return ajax_response(
        response=final_response,
        status=200
    )


@blueprint.route(
    '/cancel_query/<int:sid>/<int:pid>', methods=['DELETE']
)
@blueprint.route(
    '/cancel_query/<int:sid>/<int:did>/<int:pid>', methods=['DELETE']
)
@pga_login_required
@check_precondition
def cancel_query(sid=None, did=None, pid=None):
    """
    This function cancel the specific session
    :param sid: server id
    :param did: database id
    :param pid: session/process id
    :return: Response
    """
    sql = "SELECT pg_catalog.pg_cancel_backend({0});".format(pid)
    status, res = g.conn.execute_scalar(sql)
    if not status:
        return internal_server_error(errormsg=res)

    return ajax_response(
        response=gettext("Success") if res else gettext("Failed"),
        status=200
    )


@blueprint.route(
    '/terminate_session/<int:sid>/<int:pid>', methods=['DELETE']
)
@blueprint.route(
    '/terminate_session/<int:sid>/<int:did>/<int:pid>', methods=['DELETE']
)
@pga_login_required
@check_precondition
def terminate_session(sid=None, did=None, pid=None):
    """
    This function terminate the specific session
    :param sid: server id
    :param did: database id
    :param pid: session/process id
    :return: Response
    """
    sql = "SELECT pg_catalog.pg_terminate_backend({0});".format(pid)
    status, res = g.conn.execute_scalar(sql)
    if not status:
        return internal_server_error(errormsg=res)

    return ajax_response(
        response=gettext("Success") if res else gettext("Failed"),
        status=200
    )


# To check whether system stats extesion is present or not
@blueprint.route('check_extension/system_statistics',
                 endpoint='check_system_statistics', methods=['GET'])
@blueprint.route('check_extension/system_statistics/<int:sid>',
                 endpoint='check_system_statistics_sid', methods=['GET'])
@blueprint.route('check_extension/system_statistics/<int:sid>/<int:did>',
                 endpoint='check_system_statistics_did', methods=['GET'])
@pga_login_required
@check_precondition
def check_system_statistics(sid=None, did=None):
    sql = "SELECT * FROM pg_extension WHERE extname = 'system_stats';"
    status, res = g.conn.execute_scalar(sql)
    if not status:
        return internal_server_error(errormsg=res)
    data = {}
    if res is not None:
        data['ss_present'] = True
    else:
        data['ss_present'] = False
    return ajax_response(
        response=data,
        status=200
    )


# System Statistics Backend
@blueprint.route('/system_statistics',
                 endpoint='system_statistics', methods=['GET'])
@blueprint.route('/system_statistics/<int:sid>',
                 endpoint='system_statistics_sid', methods=['GET'])
@blueprint.route('/system_statistics/<int:sid>/<int:did>',
                 endpoint='system_statistics_did', methods=['GET'])
@pga_login_required
@check_precondition
def system_statistics(sid=None, did=None):
    resp_data = {}

    if request.args['chart_names'] != '':
        chart_names = request.args['chart_names'].split(',')

        if not sid:
            return internal_server_error(
                errormsg=ERROR_SERVER_ID_NOT_SPECIFIED)

        sql = render_template(
            "/".join([g.template_path, 'system_statistics.sql']), did=did,
            chart_names=chart_names,
        )
        status, res = g.conn.execute_dict(sql)

        if not status:
            return internal_server_error(errormsg=str(res))

        for chart_row in res['rows']:
            resp_data[chart_row['chart_name']] = json.loads(
                chart_row['chart_data'])

    return ajax_response(
        response=resp_data,
        status=200
    )


@blueprint.route('/replication_stats/<int:sid>',
                 endpoint='replication_stats', methods=['GET'])
@pga_login_required
@check_precondition
def replication_stats(sid=None):
    """
    This function is used to list all the Replication slots of the cluster
    """

    if not sid:
        return internal_server_error(errormsg=ERROR_SERVER_ID_NOT_SPECIFIED)

    sql = render_template("/".join([g.template_path, 'replication_stats.sql']))
    status, res = g.conn.execute_dict(sql)

    if not status:
        return internal_server_error(errormsg=str(res))

    return ajax_response(
        response=res['rows'],
        status=200
    )


@blueprint.route('/replication_slots/<int:sid>',
                 endpoint='replication_slots', methods=['GET'])
@pga_login_required
@check_precondition
def replication_slots(sid=None):
    """
    This function is used to list all the Replication slots of the cluster
    """

    if not sid:
        return internal_server_error(errormsg=ERROR_SERVER_ID_NOT_SPECIFIED)

    sql = render_template("/".join([g.template_path, 'replication_slots.sql']))
    status, res = g.conn.execute_dict(sql)

    if not status:
        return internal_server_error(errormsg=str(res))

    return ajax_response(
        response=res['rows'],
        status=200
    )


@blueprint.route('/job_monitor/<int:sid>', endpoint='job_monitor')
@pga_login_required
@check_precondition
def job_monitor(sid=None):
    """
    This function returns job monitor data
    :param sid: server id
    :return: Response
    """
    try:
        # Check if pgAgent extension is available
        status, res = g.conn.execute_scalar(
            "SELECT COUNT(*) FROM pg_catalog.pg_namespace WHERE nspname = 'pgagent'"
        )
        
        if not status or int(res) == 0:
            return make_json_response(
                success=0,
                errormsg=gettext("pgAgent extension not found. Please make sure it is installed."),
                status=404
            )
            
        # Debug: Let's check if the tables exist
        status, tables = g.conn.execute_dict(
            "SELECT table_name FROM information_schema.tables WHERE table_schema = 'pgagent'"
        )
        
        if not status or len(tables['rows']) == 0:
            return make_json_response(
                success=0,
                errormsg=gettext("pgAgent tables not found. Please make sure pgAgent is properly installed."),
                status=404
            )
        
        # Get table structure for debugging
        table_info = {}
        for table in tables['rows']:
            table_name = table['table_name']
            status, columns = g.conn.execute_dict(
                "SELECT column_name, data_type FROM information_schema.columns "
                "WHERE table_schema = 'pgagent' AND table_name = %s",
                (table_name,)
            )
            if status:
                table_info[table_name] = columns['rows']
        
        # Try a simpler query first to test
        status, job_count = g.conn.execute_scalar(
            "SELECT COUNT(*) FROM pgagent.pga_job"
        )
        
        if not status:
            return make_json_response(
                success=0,
                errormsg=gettext("Error accessing pgAgent job table: {}".format(job_count)),
                status=500
            )
            
        # If we got here, we can try the full query
        status, res = g.conn.execute_dict(
            render_template(
                "/".join([g.template_path, 'job_monitor.sql'])
            )
        )

        if not status:
            return make_json_response(
                success=0,
                errormsg=gettext("Error executing job monitor query: {}".format(res)),
                status=500
            )
            
        # Log the structure of the result for debugging
        if 'rows' in res and len(res['rows']) > 0:
            first_row = res['rows'][0]
            # Check if the result column exists
            if 'result' in first_row:
                # Extract the result JSON
                result_json = first_row['result']
                
                # Check if result_json is a string and try to parse it
                if isinstance(result_json, str):
                    try:
                        import json
                        result_json = json.loads(result_json)
                    except Exception as e:
                        return make_json_response(
                            success=0,
                            errormsg=gettext("Error parsing JSON result: {}".format(str(e))),
                            status=500
                        )
                
                # Return the result directly
                return ajax_response(
                    response={
                        'debug_info': {
                            'tables': tables['rows'],
                            'table_info': table_info,
                            'job_count': job_count,
                            'raw_result': first_row
                        },
                        'data': result_json
                    },
                    status=200
                )
            else:
                # Log the available columns
                available_columns = list(first_row.keys())
                return make_json_response(
                    success=0,
                    errormsg=gettext("Expected 'result' column not found in query result. Available columns: {}".format(available_columns)),
                    status=500
                )
        else:
            # No rows returned
            return ajax_response(
                response={
                    'debug_info': {
                        'tables': tables['rows'],
                        'table_info': table_info,
                        'job_count': job_count,
                        'message': 'No rows returned from query'
                    },
                    'data': {
                        'summary': {
                            'total_jobs': 0,
                            'enabled_jobs': 0,
                            'disabled_jobs': 0,
                            'running_jobs': 0,
                            'successful_jobs': 0,
                            'failed_jobs': 0
                        },
                        'jobs': []
                    }
                },
                status=200
            )
    except Exception as e:
        import traceback
        error_traceback = traceback.format_exc()
        return make_json_response(
            success=0,
            errormsg=str(e),
            info=error_traceback,
            status=500
        )


@blueprint.route('/run_job/<int:sid>/<int:jobid>', methods=['POST'], endpoint='run_job')
@pga_login_required
@check_precondition
def run_job(sid=None, jobid=None):
    """
    This function runs a specific pgAgent job
    :param sid: server id
    :param jobid: job id
    :return: Response
    """
    try:
        if jobid is None:
            return make_json_response(
                success=0,
                errormsg=gettext("Job ID not specified"),
                status=400
            )

        # Check if pgAgent extension is available
        status, res = g.conn.execute_scalar(
            "SELECT COUNT(*) FROM pg_catalog.pg_namespace WHERE nspname = 'pgagent'"
        )
        
        if not status or int(res) == 0:
            return make_json_response(
                success=0,
                errormsg=gettext("pgAgent extension not found. Please make sure it is installed."),
                status=404
            )
        
        # Check if the job exists
        status, job_exists = g.conn.execute_scalar(
            "SELECT COUNT(*) FROM pgagent.pga_job WHERE jobid = %s",
            (jobid,)
        )
        
        if not status or int(job_exists) == 0:
            return make_json_response(
                success=0,
                errormsg=gettext("Job with ID {} not found".format(jobid)),
                status=404
            )
            
        # Run the job by calling pgagent function
        status, res = g.conn.execute_scalar(
            "SELECT pgagent.pga_run_job(%s)",
            (jobid,)
        )
        
        if not status:
            return make_json_response(
                success=0,
                errormsg=gettext("Error running job: {}".format(res)),
                status=500
            )
            
        return make_json_response(
            success=1,
            info=gettext("Job started successfully"),
            data={'jobid': jobid}
        )
        
    except Exception as e:
        import traceback
        error_traceback = traceback.format_exc()
        return make_json_response(
            success=0,
            errormsg=str(e),
            info=error_traceback,
            status=500
        )


@blueprint.route('/job_log/<int:sid>/<int:jobid>', methods=['GET'], endpoint='job_log')
@pga_login_required
@check_precondition
def job_log(sid=None, jobid=None):
    """
    This function returns the log for a specific pgAgent job
    :param sid: server id
    :param jobid: job id
    :return: Response
    """
    try:
        if jobid is None:
            return make_json_response(
                success=0,
                errormsg=gettext("Job ID not specified"),
                status=400
            )

        # Check if pgAgent extension is available
        status, res = g.conn.execute_scalar(
            "SELECT COUNT(*) FROM pg_catalog.pg_namespace WHERE nspname = 'pgagent'"
        )
        
        if not status or int(res) == 0:
            return make_json_response(
                success=0,
                errormsg=gettext("pgAgent extension not found. Please make sure it is installed."),
                status=404
            )
        
        # Check if the job exists
        status, job_exists = g.conn.execute_scalar(
            "SELECT COUNT(*) FROM pgagent.pga_job WHERE jobid = %s",
            (jobid,)
        )
        
        if not status or int(job_exists) == 0:
            return make_json_response(
                success=0,
                errormsg=gettext("Job with ID {} not found".format(jobid)),
                status=404
            )
            
        # Get job log details
        status, job_log = g.conn.execute_dict(
            """
            SELECT 
                j.jobname, 
                jl.jlgid, 
                jl.jlgjobid,
                CASE 
                    WHEN jl.jlgstatus = 'r' THEN 'Running'
                    WHEN jl.jlgstatus = 's' THEN 'Success'
                    WHEN jl.jlgstatus = 'f' THEN 'Failed'
                    WHEN jl.jlgstatus = 'i' THEN 'Internal Error'
                    WHEN jl.jlgstatus = 'd' THEN 'Aborted'
                    ELSE jl.jlgstatus
                END AS status,
                jl.jlgstart,
                jl.jlgduration,
                array_agg(
                    json_build_object(
                        'step_id', js.jstid,
                        'step_name', js.jstname,
                        'step_desc', js.jstdesc,
                        'status', CASE 
                                    WHEN jsl.jslstatus = 'r' THEN 'Running'
                                    WHEN jsl.jslstatus = 's' THEN 'Success'
                                    WHEN jsl.jslstatus = 'f' THEN 'Failed'
                                    WHEN jsl.jslstatus = 'i' THEN 'Internal Error'
                                    WHEN jsl.jslstatus = 'd' THEN 'Aborted'
                                    ELSE jsl.jslstatus
                                 END,
                        'start_time', jsl.jslstart,
                        'duration', jsl.jslduration,
                        'output', jsl.jslresult
                    )
                ) AS steps
            FROM 
                pgagent.pga_job j
            JOIN 
                pgagent.pga_joblog jl ON j.jobid = jl.jlgjobid
            LEFT JOIN 
                pgagent.pga_jobsteplog jsl ON jl.jlgid = jsl.jsljlgid
            LEFT JOIN 
                pgagent.pga_jobstep js ON jsl.jsljstid = js.jstid
            WHERE 
                j.jobid = %s
            GROUP BY 
                j.jobname, jl.jlgid, jl.jlgjobid, jl.jlgstatus, jl.jlgstart, jl.jlgduration
            ORDER BY 
                jl.jlgstart DESC
            LIMIT 10
            """,
            (jobid,)
        )
        
        if not status:
            return make_json_response(
                success=0,
                errormsg=gettext("Error retrieving job log: {}".format(job_log)),
                status=500
            )
            
        return make_json_response(
            success=1,
            data=job_log
        )
        
    except Exception as e:
        import traceback
        error_traceback = traceback.format_exc()
        return make_json_response(
            success=0,
            errormsg=str(e),
            info=error_traceback,
            status=500
        )


@blueprint.route('/audit_logs/<int:sid>',
                 endpoint='audit_logs', methods=['GET'])
@pga_login_required
@check_precondition
def audit_logs(sid=None):
    """
    This function returns pgAgent audit logs with optional filtering
    :param sid: server id
    :return: JSON response with audit logs or file download for export
    """
    
    if not sid:
        return internal_server_error(errormsg=ERROR_SERVER_ID_NOT_SPECIFIED)
    
    # Get filter parameters from request
    operation = request.args.get('operation', None)
    username = request.args.get('username', None)
    jobname = request.args.get('jobname', None)
    start_date = request.args.get('start_date', None)
    end_date = request.args.get('end_date', None)
    
    # Check if export is requested
    export = request.args.get('export', 'false').lower() == 'true'
    export_format = request.args.get('format', 'json').lower()
    
    # Prepare template parameters
    params = {
        'operation': operation,
        'username': username,
        'jobname': jobname,
        'start_date': start_date,
        'end_date': end_date
    }
    
    sql = render_template("/".join(['dashboard/sql/default', 'audit_logs.sql']), **params)
    status, res = g.conn.execute_dict(sql)
    
    if not status:
        return internal_server_error(errormsg=str(res))
    
    # If export is requested, return the data in the requested format
    if export:
        if export_format == 'json':
            # For JSON export
            import json
            response_data = json.dumps(res['rows'], indent=2)
            response = Response(response_data, mimetype='application/json')
            response.headers['Content-Disposition'] = 'attachment; filename=pgagent_audit_logs.json'
            return response
        elif export_format == 'csv':
            # For CSV export
            import csv
            import io
            
            output = io.StringIO()
            if res['rows']:
                # Get column names from the first row
                fieldnames = res['rows'][0].keys()
                writer = csv.DictWriter(output, fieldnames=fieldnames)
                writer.writeheader()
                writer.writerows(res['rows'])
            
            response = Response(output.getvalue(), mimetype='text/csv')
            response.headers['Content-Disposition'] = 'attachment; filename=pgagent_audit_logs.csv'
            return response
    
    # Default response for non-export requests
    return ajax_response(
        response=res['rows'],
        status=200
    )

@blueprint.route('/job_names/<int:sid>',
                 endpoint='job_names', methods=['GET'])
@pga_login_required
@check_precondition
def job_names(sid=None):
    """
    This function returns all pgAgent job names for the dropdown
    :param sid: server id
    :return: JSON response with job names
    """
    
    if not sid:
        return internal_server_error(errormsg=ERROR_SERVER_ID_NOT_SPECIFIED)
    
    sql = render_template("/".join(['dashboard/sql/default', 'job_names.sql']))
    status, res = g.conn.execute_dict(sql)
    
    if not status:
        return internal_server_error(errormsg=str(res))
    
    return ajax_response(
        response=res['rows'],
        status=200
    )

@blueprint.route("/job_dependency_graph/<int:sid>", endpoint='job_dependency_graph')
@pga_login_required
@check_precondition
def job_dependency_graph(sid):
    """Get the job dependency graph data."""
    try:
        if not sid:
            return internal_server_error(errormsg=ERROR_SERVER_ID_NOT_SPECIFIED)

        # Get all jobs
        status, jobs = g.conn.execute_dict(
            render_template(
                "/".join([g.template_path, 'jobs.sql'])
            )
        )
        if not status:
            return internal_server_error(errormsg=jobs)

        # Get all dependencies
        status, deps = g.conn.execute_dict(
            render_template(
                "/".join([g.template_path, 'dependencies.sql'])
            )
        )
        if not status:
            return internal_server_error(errormsg=deps)

        # Build the graph data
        nodes = []
        edges = []
        
        # Add nodes for all jobs
        for job in jobs['rows']:
            nodes.append({
                'id': job['jobid'],
                'name': job['jobname'],
                'enabled': job['jobenabled'],
                'status': job['status'],
                'next_run': job['jobnextrun'],
                'last_run': job['joblastrun']
            })

        # Add edges for all dependencies
        for dep in deps['rows']:
            edges.append({
                'source': dep['jobid'],
                'target': dep['dependent_jobid'],
                'dependent_jobname': dep['dependent_jobname']
            })

        return ajax_response(
            response={
                'dependency_graph': {
                    'nodes': nodes,
                    'links': edges
                }
            },
            status=200
        )

    except Exception as e:
        return internal_server_error(errormsg=str(e))