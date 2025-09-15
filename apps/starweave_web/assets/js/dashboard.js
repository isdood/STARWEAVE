// Initialize Chart.js for the DETS dashboard
function initDashboardChart() {
  const ctxEl = document.getElementById('context-chart');
  if (!ctxEl) return;

  const ctx = ctxEl.getContext('2d');
  
  window.memoryChart = new window.Chart(ctx, {
    type: 'doughnut',
    data: {
      labels: [],
      datasets: [{
        data: [],
        backgroundColor: [
          'rgba(59, 130, 246, 0.8)',
          'rgba(16, 185, 129, 0.8)',
          'rgba(245, 158, 11, 0.8)',
          'rgba(239, 68, 68, 0.8)',
          'rgba(139, 92, 246, 0.8)',
        ],
        borderWidth: 1
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          position: 'right',
        },
        tooltip: {
          callbacks: {
            label: function(context) {
              const label = context.label || '';
              const value = context.raw || 0;
              const total = context.dataset.data.reduce((a, b) => a + b, 0);
              const percentage = Math.round((value / total) * 100);
              return `${label}: ${value} (${percentage}%)`;
            }
          }
        }
      }
    }
  });
}

// Update chart data
function updateChartData(labels, data) {
  if (window.memoryChart) {
    window.memoryChart.data.labels = labels;
    window.memoryChart.data.datasets[0].data = data;
    window.memoryChart.update();
  } else {
    initDashboardChart();
    // Try again after a short delay to ensure chart is initialized
    setTimeout(() => updateChartData(labels, data), 100);
  }
}

// Initialize when the page loads
document.addEventListener('DOMContentLoaded', () => {
  initDashboardChart();
  
  // Handle LiveView updates
  if (window.liveSocket) {
    window.liveSocket.enableDebug();
    window.liveSocket.enableLatencySim(1000);
  }
});

// Export functions for LiveView hooks
window.DashboardChart = {
  init: initDashboardChart,
  update: updateChartData
};
