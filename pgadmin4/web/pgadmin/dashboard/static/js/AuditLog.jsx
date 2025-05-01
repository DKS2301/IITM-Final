import React, { useState, useEffect } from 'react';
import PropTypes from 'prop-types';
import gettext from 'sources/gettext';
import url_for from 'sources/url_for';
import getApiInstance from 'sources/api_instance';
import { 
  Box, 
  FormControl, 
  InputLabel, 
  MenuItem, 
  Select, 
  TextField, 
  Button, 
  Paper, 
  Typography,
  Grid,
  Autocomplete,
  Chip,
  IconButton,
  InputAdornment,
  Popover
} from '@mui/material';
import PgTable from 'sources/components/PgTable';
import { PgIconButton } from '../../../static/js/components/Buttons';
import ContentCopyIcon from '@mui/icons-material/ContentCopy';
import CalendarTodayIcon from '@mui/icons-material/CalendarToday';
import FilterAltIcon from '@mui/icons-material/FilterAlt';
import RestartAltIcon from '@mui/icons-material/RestartAlt';
import EventIcon from '@mui/icons-material/Event';
import EmptyPanelMessage from '../../../static/js/components/EmptyPanelMessage';
import GetAppRoundedIcon from '@mui/icons-material/GetAppRounded';
import { downloadFile } from '../../../static/js/utils';

// Define styles as objects instead of using makeStyles
const styles = {
  filterContainer: {
    marginBottom: '16px',
    padding: '20px',
    backgroundColor: '#f8f9fa',
    borderRadius: '8px',
    boxShadow: '0 3px 6px rgba(0,0,0,0.1)',
  },
  filterGrid: {
    marginBottom: '16px',
  },
  filterItem: {
    minWidth: '200px',
  },
  filterActions: {
    display: 'flex',
    justifyContent: 'flex-end',
    gap: '8px',
    marginTop: '16px',
  },
  filterButton: {
    textTransform: 'none',
    borderRadius: '6px',
    padding: '6px 16px',
  },
  filterTitle: {
    fontSize: '18px',
    fontWeight: 600,
    color: '#2c5aa0',
    marginBottom: '20px',
    borderBottom: '2px solid #e0e0e0',
    paddingBottom: '10px',
  },
  filterLabel: {
    fontWeight: 500,
    color: '#4a4a4a',
  },
  filterSelect: {
    '& .MuiOutlinedInput-root': {
      borderRadius: '6px',
      backgroundColor: '#ffffff',
    },
  },
  filterInput: {
    '& .MuiOutlinedInput-root': {
      borderRadius: '6px',
      backgroundColor: '#ffffff',
    },
  },
  tableContainer: {
    flex: 1,
    overflow: 'auto',
    borderRadius: '8px',
    boxShadow: '0 2px 4px rgba(0,0,0,0.05)',
  },
  headerCell: {
    fontWeight: 'bold',
    backgroundColor: '#f1f3f5',
  },
  chip: {
    margin: '2px',
  },
  title: {
    marginBottom: '16px',
    fontWeight: 'bold',
    color: '#4a4a4a',
  },
  calendar: {
    padding: '16px',
    width: '300px',
  },
  datePickerHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '8px',
  },
  datePickerGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(7, 1fr)',
    gap: '4px',
  },
  dateCell: {
    width: '36px',
    height: '36px',
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    cursor: 'pointer',
    borderRadius: '50%',
    '&:hover': {
      backgroundColor: '#e0e0e0',
    },
  },
  selectedDate: {
    backgroundColor: '#1976d2',
    color: 'white',
    '&:hover': {
      backgroundColor: '#1565c0',
    },
  },
  dayHeader: {
    fontWeight: 'bold',
    textAlign: 'center',
    padding: '4px 0',
  },
  timeInput: {
    marginTop: '16px',
  },
};

// Simple date picker component
function DatePicker({ selectedDate, onChange, onClose }) {
  const [date, setDate] = useState(selectedDate ? new Date(selectedDate) : new Date());
  const [time, setTime] = useState(selectedDate ? 
    new Date(selectedDate).toTimeString().slice(0, 5) : 
    '00:00');
  
  const handleDateChange = (newDate) => {
    setDate(newDate);
  };
  
  const handleTimeChange = (e) => {
    setTime(e.target.value);
  };
  
  const handleApply = () => {
    const dateTime = new Date(date);
    const [hours, minutes] = time.split(':');
    dateTime.setHours(parseInt(hours, 10));
    dateTime.setMinutes(parseInt(minutes, 10));
    
    // Format as YYYY-MM-DD HH:MM:SS
    const formattedDate = dateTime.toISOString().slice(0, 19).replace('T', ' ');
    onChange(formattedDate);
    onClose();
  };
  
  const daysInMonth = (year, month) => new Date(year, month + 1, 0).getDate();
  const firstDayOfMonth = (year, month) => new Date(year, month, 1).getDay();
  
  const renderCalendar = () => {
    const year = date.getFullYear();
    const month = date.getMonth();
    const today = new Date();
    const days = daysInMonth(year, month);
    const firstDay = firstDayOfMonth(year, month);
    
    const dayNames = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    const prevMonth = () => {
      const newDate = new Date(date);
      newDate.setMonth(newDate.getMonth() - 1);
      setDate(newDate);
    };
    
    const nextMonth = () => {
      const newDate = new Date(date);
      newDate.setMonth(newDate.getMonth() + 1);
      setDate(newDate);
    };
    
    const isSelected = (day) => {
      return date.getDate() === day;
    };
    
    return (
      <Box>
        <Box sx={styles.datePickerHeader}>
          <IconButton onClick={prevMonth} size="small">
            &lt;
          </IconButton>
          <Typography variant="subtitle1">
            {monthNames[month]} {year}
          </Typography>
          <IconButton onClick={nextMonth} size="small">
            &gt;
          </IconButton>
        </Box>
        
        <Box sx={styles.datePickerGrid}>
          {dayNames.map(day => (
            <Box key={day} sx={styles.dayHeader}>{day}</Box>
          ))}
          
          {Array.from({ length: firstDay }).map((_, i) => (
            <Box key={`empty-${i}`} />
          ))}
          
          {Array.from({ length: days }).map((_, i) => {
            const day = i + 1;
            return (
              <Box 
                key={day} 
                sx={{
                  ...styles.dateCell,
                  ...(isSelected(day) ? styles.selectedDate : {}),
                }}
                onClick={() => {
                  const newDate = new Date(date);
                  newDate.setDate(day);
                  handleDateChange(newDate);
                }}
              >
                {day}
              </Box>
            );
          })}
        </Box>
        
        <TextField
          label="Time"
          type="time"
          value={time}
          onChange={handleTimeChange}
          fullWidth
          sx={styles.timeInput}
          InputLabelProps={{ shrink: true }}
        />
        
        <Box sx={{ display: 'flex', justifyContent: 'flex-end', marginTop: '16px' }}>
          <Button onClick={onClose} sx={{ marginRight: '8px' }}>
            Cancel
          </Button>
          <Button variant="contained" onClick={handleApply}>
            Apply
          </Button>
        </Box>
      </Box>
    );
  };
  
  return (
    <Paper sx={styles.calendar}>
      {renderCalendar()}
    </Paper>
  );
};

function AuditLog({ sid, treeNodeInfo, pageVisible }) {
  const api = getApiInstance();
  
  const [auditLogs, setAuditLogs] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  
  // Filter states
  const [operation, setOperation] = useState('');
  const [username, setUsername] = useState('');
  const [jobname, setJobname] = useState('');
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  
  // For job name dropdown
  const [jobNames, setJobNames] = useState([]);
  const [uniqueUsernames, setUniqueUsernames] = useState([]);
  
  // Date picker popover states
  const [startDateAnchorEl, setStartDateAnchorEl] = useState(null);
  const [endDateAnchorEl, setEndDateAnchorEl] = useState(null);
  const openStartDatePicker = Boolean(startDateAnchorEl);
  const openEndDatePicker = Boolean(endDateAnchorEl);
  
  const handleStartDateClick = (event) => {
    setStartDateAnchorEl(event.currentTarget);
  };
  
  const handleEndDateClick = (event) => {
    setEndDateAnchorEl(event.currentTarget);
  };
  
  const handleStartDateClose = () => {
    setStartDateAnchorEl(null);
  };
  
  const handleEndDateClose = () => {
    setEndDateAnchorEl(null);
  };

  // Fetch all job names for the dropdown
  const fetchJobNames = () => {
    if (!sid) return;
    
    // First fetch actual job names from the database
    api({
      url: url_for('dashboard.job_names', {'sid': sid}),
      method: 'GET',
    })
      .then((jobRes) => {
        // Create a map of job IDs to job names
        const jobNameMap = new Map();
        jobRes.data.forEach(job => {
          jobNameMap.set(job.jobid, job.jobname);
        });
        
        // Now fetch audit logs to get usernames
        return api({
          url: url_for('dashboard.audit_logs', {'sid': sid}),
          method: 'GET',
        })
          .then((auditRes) => {
            // Extract unique usernames
            const usernames = [...new Set(auditRes.data.map(log => log.operation_user))];
            setUniqueUsernames(usernames);
            
            // Get unique job IDs from audit logs
            const uniqueJobIds = [...new Set(auditRes.data.map(log => log.job_id))];
            
            // Create dropdown options
            const jobNameOptions = [];
            
            // First add all jobs with names from the database
            uniqueJobIds.forEach(id => {
              if (jobNameMap.has(id)) {
                const jobName = jobNameMap.get(id);
                jobNameOptions.push({
                  id: id,
                  name: jobName,
                  display: jobName
                });
              } else if (id) {
                // For jobs without names, just use the ID
                jobNameOptions.push({
                  id: id,
                  name: `Job ID: ${id}`,
                  display: `Job ID: ${id}`
                });
              }
            });
            
            // Sort by job name
            jobNameOptions.sort((a, b) => a.display.localeCompare(b.display));
            
            setJobNames(jobNameOptions);
          });
      })
      .catch((err) => {
        console.error('Failed to fetch job names:', err);
        
        // Fallback to just fetching audit logs
        api({
          url: url_for('dashboard.audit_logs', {'sid': sid}),
          method: 'GET',
        })
          .then((res) => {
            // Extract unique usernames
            const usernames = [...new Set(res.data.map(log => log.operation_user))];
            setUniqueUsernames(usernames);
            
            // Extract job IDs as fallback
            const uniqueJobIds = [...new Set(res.data.map(log => log.job_id))];
            const jobNameOptions = uniqueJobIds
              .filter(id => id)
              .map(id => ({
                id: id,
                name: `Job ID: ${id}`,
                display: `Job ID: ${id}`
              }));
            
            setJobNames(jobNameOptions);
          })
          .catch(() => {
            console.error('Failed to fetch audit logs as fallback');
          });
      });
  };

  const fetchAuditLogs = () => {
    if (!sid) return;
    
    setLoading(true);
    setError(null);
    
    // Build query parameters
    let params = new URLSearchParams();
    if (operation) params.append('operation', operation);
    if (username) params.append('username', username);
    
    // We're already storing the job ID in jobname
    if (jobname) {
      params.append('jobname', jobname);
    }
    
    if (startDate) params.append('start_date', startDate);
    if (endDate) params.append('end_date', endDate);
    
    const url = url_for('dashboard.audit_logs', {'sid': sid}) + '?' + params.toString();
    
    api({
      url: url,
      method: 'GET',
    })
      .then((res) => {
        setAuditLogs(res.data);
        setLoading(false);
      })
      .catch((err) => {
        setError(err.message || 'Failed to fetch audit logs');
        setLoading(false);
      });
  };

  useEffect(() => {
    if (pageVisible) {
      fetchJobNames();
      fetchAuditLogs();
    }
  }, [pageVisible, sid]);

  const handleCopyToClipboard = (text) => {
    navigator.clipboard.writeText(text)
      .then(() => {
        // Success notification could be added here
      })
      .catch((err) => {
        console.error('Failed to copy text: ', err);
      });
  };

  const handleReset = () => {
    setOperation('');
    setUsername('');
    setJobname('');
    setStartDate('');
    setEndDate('');
  };

  const handleExport = (format) => {
    if (!sid) return;
    
    // Build query parameters for filtering
    let params = new URLSearchParams();
    if (operation) params.append('operation', operation);
    if (username) params.append('username', username);
    
    // We're already storing the job ID in jobname
    if (jobname) {
      params.append('jobname', jobname);
    }
    
    if (startDate) params.append('start_date', startDate);
    if (endDate) params.append('end_date', endDate);
    
    // Show loading state
    setLoading(true);
    
    // Use the API instance to make the request with proper authentication
    api({
      url: url_for('dashboard.audit_logs', {'sid': sid}) + '?' + params.toString(),
      method: 'GET',
    })
      .then((response) => {
        const data = response.data;
        let fileName = `pgagent_audit_logs_${new Date().getTime()}`;
        let contentType = 'text/plain';
        let content = '';
        
        if (format === 'json') {
          fileName += '.json';
          contentType = 'application/json';
          content = JSON.stringify(data, null, 2);
        } else if (format === 'csv') {
          fileName += '.csv';
          contentType = 'text/csv';
          
          // Create CSV content
          if (data && data.length > 0) {
            // Get headers from the first row
            const headers = Object.keys(data[0]);
            content = headers.join(',') + '\n';
            
            // Add data rows
            data.forEach(row => {
              const rowValues = headers.map(header => {
                let value = row[header];
                // Handle special cases for CSV formatting
                if (value === null || value === undefined) {
                  return '';
                } else if (typeof value === 'object') {
                  value = JSON.stringify(value);
                }
                // Escape quotes and wrap in quotes if contains comma
                value = String(value).replace(/"/g, '""');
                if (value.includes(',') || value.includes('\n') || value.includes('"')) {
                  value = `"${value}"`;
                }
                return value;
              });
              content += rowValues.join(',') + '\n';
            });
          }
        }
        
        // Download the file
        downloadFile(content, fileName, contentType);
        setLoading(false);
        
        // Show success notification
        if (window.pgAdmin && window.pgAdmin.Browser) {
          window.pgAdmin.Browser.notifier.success(
            gettext(`Successfully exported audit logs in ${format.toUpperCase()} format`)
          );
        }
      })
      .catch((error) => {
        console.error('Export failed:', error);
        setLoading(false);
        
        // Show error notification
        if (window.pgAdmin && window.pgAdmin.Browser) {
          window.pgAdmin.Browser.notifier.error(
            gettext(`Failed to export audit logs: ${error.message}`)
          );
        }
      });
  };

  const columns = [
    {
      accessorKey: 'audit_id',
      header: gettext('ID'),
      enableSorting: true,
      enableResizing: true,
      size: 80,
    },
    {
      accessorKey: 'operation_time',
      header: gettext('Timestamp'),
      enableSorting: true,
      enableResizing: true,
      size: 180,
    },
    {
      accessorKey: 'operation_type',
      header: gettext('Operation'),
      enableSorting: true,
      enableResizing: true,
      size: 100,
    },
    {
      accessorKey: 'job_id',
      header: gettext('Job ID'),
      enableSorting: true,
      enableResizing: true,
      size: 80,
    },
    {
      accessorKey: 'operation_user',
      header: gettext('Username'),
      enableSorting: true,
      enableResizing: true,
      size: 120,
    },
    {
      accessorKey: 'additional_info',
      header: gettext('Additional Info'),
      enableSorting: true,
      enableResizing: true,
      minSize: 200,
    },
    {
      id: 'actions',
      header: gettext('Actions'),
      enableSorting: false,
      enableResizing: false,
      size: 80,
      cell: ({ row }) => {
        const logEntry = JSON.stringify(row.original, null, 2);
        return (
          <PgIconButton
            title={gettext('Copy to clipboard')}
            icon={<ContentCopyIcon />}
            size="xs"
            onClick={() => handleCopyToClipboard(logEntry)}
          />
        );
      },
    },
  ];

  return (
    <Box sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <Paper sx={styles.filterContainer}>
        <Typography variant="h6" sx={styles.filterTitle}>
          {gettext('Audit Log Filters')}
        </Typography>
        
        <Grid container spacing={2} sx={styles.filterGrid}>
          {/* Job Name Dropdown - First position */}
          <Grid item xs={12} sm={6} md={4}>
            <Autocomplete
              options={jobNames}
              value={jobNames.find(option => option.id === parseInt(jobname)) || 
                    jobNames.find(option => option.name === jobname) || null}
              onChange={(event, newValue) => setJobname(newValue ? newValue.id.toString() : '')}
              getOptionLabel={(option) => option.display || ''}
              isOptionEqualToValue={(option, value) => option.id === value.id}
              renderInput={(params) => (
                <TextField 
                  {...params} 
                  label={gettext('Job Name')} 
                  size="small"
                  fullWidth
                  sx={styles.filterInput}
                  InputLabelProps={{
                    shrink: true,
                    sx: styles.filterLabel
                  }}
                />
              )}
              ListboxProps={{
                style: { maxHeight: '200px' }
              }}
            />
          </Grid>
          
          {/* Username Dropdown */}
          <Grid item xs={12} sm={6} md={4}>
            <Autocomplete
              options={uniqueUsernames}
              value={username}
              onChange={(event, newValue) => setUsername(newValue || '')}
              renderInput={(params) => (
                <TextField 
                  {...params} 
                  label={gettext('Username')} 
                  size="small"
                  fullWidth
                  sx={styles.filterInput}
                  InputLabelProps={{
                    shrink: true,
                    sx: styles.filterLabel
                  }}
                />
              )}
              ListboxProps={{
                style: { maxHeight: '200px' }
              }}
            />
          </Grid>
          
          {/* Operation Type Dropdown */}
          <Grid item xs={12} sm={6} md={4}>
            <FormControl fullWidth size="small" sx={styles.filterSelect}>
              <InputLabel id="operation-label" shrink sx={styles.filterLabel}>
                {gettext('Operation Type')}
              </InputLabel>
              <Select
                labelId="operation-label"
                value={operation}
                label={gettext('Operation Type')}
                onChange={(e) => setOperation(e.target.value)}
                notched
              >
                <MenuItem value="">{gettext('All Operations')}</MenuItem>
                <MenuItem value="CREATE">{gettext('CREATE')}</MenuItem>
                <MenuItem value="MODIFY">{gettext('MODIFY')}</MenuItem>
                <MenuItem value="DELETE">{gettext('DELETE')}</MenuItem>
                <MenuItem value="EXECUTE">{gettext('EXECUTE')}</MenuItem>
              </Select>
            </FormControl>
          </Grid>
          
          {/* Start Date Picker */}
          <Grid item xs={12} sm={6} md={4}>
            <TextField
              fullWidth
              label={gettext('Start Date')}
              value={startDate}
              onChange={(e) => setStartDate(e.target.value)}
              placeholder="YYYY-MM-DD HH:MM:SS"
              size="small"
              sx={styles.filterInput}
              InputLabelProps={{
                shrink: true,
                sx: styles.filterLabel
              }}
              InputProps={{
                endAdornment: (
                  <InputAdornment position="end">
                    <IconButton 
                      edge="end" 
                      onClick={handleStartDateClick}
                      size="small"
                      sx={{ color: '#2c5aa0' }}
                    >
                      <EventIcon />
                    </IconButton>
                  </InputAdornment>
                ),
              }}
            />
            <Popover
              open={openStartDatePicker}
              anchorEl={startDateAnchorEl}
              onClose={handleStartDateClose}
              anchorOrigin={{
                vertical: 'bottom',
                horizontal: 'left',
              }}
              elevation={3}
            >
              <DatePicker 
                selectedDate={startDate} 
                onChange={setStartDate} 
                onClose={handleStartDateClose} 
              />
            </Popover>
          </Grid>
          
          {/* End Date Picker */}
          <Grid item xs={12} sm={6} md={4}>
            <TextField
              fullWidth
              label={gettext('End Date')}
              value={endDate}
              onChange={(e) => setEndDate(e.target.value)}
              placeholder="YYYY-MM-DD HH:MM:SS"
              size="small"
              sx={styles.filterInput}
              InputLabelProps={{
                shrink: true,
                sx: styles.filterLabel
              }}
              InputProps={{
                endAdornment: (
                  <InputAdornment position="end">
                    <IconButton 
                      edge="end" 
                      onClick={handleEndDateClick}
                      size="small"
                      sx={{ color: '#2c5aa0' }}
                    >
                      <EventIcon />
                    </IconButton>
                  </InputAdornment>
                ),
              }}
            />
            <Popover
              open={openEndDatePicker}
              anchorEl={endDateAnchorEl}
              onClose={handleEndDateClose}
              anchorOrigin={{
                vertical: 'bottom',
                horizontal: 'left',
              }}
              elevation={3}
            >
              <DatePicker 
                selectedDate={endDate} 
                onChange={setEndDate} 
                onClose={handleEndDateClose} 
              />
            </Popover>
          </Grid>
        </Grid>
        
        <Box sx={styles.filterActions}>
          <Button 
            variant="contained" 
            onClick={fetchAuditLogs} 
            startIcon={<FilterAltIcon />}
            sx={{
              ...styles.filterButton,
              backgroundColor: '#2c5aa0',
              '&:hover': {
                backgroundColor: '#1c4a90',
              }
            }}
            size="medium"
          >
            {gettext('Apply Filters')}
          </Button>
          <Button 
            variant="outlined" 
            onClick={handleReset}
            startIcon={<RestartAltIcon />}
            sx={{
              ...styles.filterButton,
              borderColor: '#2c5aa0',
              color: '#2c5aa0',
              '&:hover': {
                borderColor: '#1c4a90',
                backgroundColor: 'rgba(44, 90, 160, 0.04)',
              }
            }}
            size="medium"
          >
            {gettext('Reset')}
          </Button>
          <Button 
            variant="outlined" 
            onClick={() => handleExport('json')} 
            startIcon={<GetAppRoundedIcon />}
            sx={{
              ...styles.filterButton,
              marginLeft: '8px',
              borderColor: '#4caf50',
              color: '#4caf50',
              '&:hover': {
                borderColor: '#388e3c',
                backgroundColor: 'rgba(76, 175, 80, 0.04)',
              }
            }}
            size="medium"
            disabled={loading}
          >
            {gettext('Export JSON')}
          </Button>
          <Button 
            variant="outlined" 
            onClick={() => handleExport('csv')} 
            startIcon={<GetAppRoundedIcon />}
            sx={{
              ...styles.filterButton,
              borderColor: '#ff9800',
              color: '#ff9800',
              '&:hover': {
                borderColor: '#f57c00',
                backgroundColor: 'rgba(255, 152, 0, 0.04)',
              }
            }}
            size="medium"
            disabled={loading}
          >
            {gettext('Export CSV')}
          </Button>
        </Box>
      </Paper>
      
      {error ? (
        <Box sx={{ p: 2 }}>
          <EmptyPanelMessage text={error} />
        </Box>
      ) : (
        <Paper sx={styles.tableContainer}>
          <PgTable
            caveTable={false}
            tableNoBorder={false}
            columns={columns}
            data={auditLogs}
            isLoading={loading}
            enableColumnFilters={true}
            enableSorting={true}
            enablePagination={true}
            enableRowSelection={false}
            enableColumnResizing={true}
            initialState={{
              pagination: {
                pageSize: 10,
                pageIndex: 0
              },
              sorting: [
                {
                  id: 'operation_time',
                  desc: true
                }
              ]
            }}
            emptyTableText={gettext('No audit logs found')}
            tableClassName="audit-log-table"
            tableStyle={{
              borderCollapse: 'separate',
              borderSpacing: 0,
            }}
            getRowId={(row) => row.audit_id}
          />
        </Paper>
      )}
    </Box>
  );
}

AuditLog.propTypes = {
  sid: PropTypes.oneOfType([PropTypes.string, PropTypes.number]).isRequired,
  treeNodeInfo: PropTypes.object.isRequired,
  pageVisible: PropTypes.bool.isRequired,
};

export default AuditLog;