import { useRef } from 'react';
import Highcharts from 'highcharts';
import HighchartsReact from 'highcharts-react-official';
import HighchartsSankey from 'highcharts/modules/sankey';

// Initialize Sankey module with type assertion
(HighchartsSankey as any)(Highcharts);

interface SankeyNode {
  label: string;
  color: string;
}

interface SankeyLinks {
  source: number[];
  target: number[];
  value: number[];
}

interface SankeyChartProps {
  nodes: SankeyNode[];
  links: SankeyLinks;
  title?: string;
  height?: number;
}

export default function SankeyChart({ nodes, links, title, height = 700 }: SankeyChartProps) {
  const chartRef = useRef<HighchartsReact.RefObject>(null);

  // Transform data to Highcharts format
  const sankeyData = links.source.map((sourceIdx, i) => ({
    from: nodes[sourceIdx].label,
    to: nodes[links.target[i]].label,
    weight: links.value[i],
  }));

  // Create node colors map (not used currently but kept for future enhancements)
  // const nodeColors = nodes.reduce((acc, node) => {
  //   acc[node.label] = node.color;
  //   return acc;
  // }, {} as Record<string, string>);

  const options: Highcharts.Options = {
    chart: {
      height: height,
      backgroundColor: 'transparent',
      animation: true,
    },
    title: {
      text: title || '',
      style: {
        display: 'none', // We handle title in React
      },
    },
    accessibility: {
      point: {
        valueDescriptionFormat: '{index}. {point.from} to {point.to}, {point.weight}.',
      },
    },
    tooltip: {
      headerFormat: '',
      pointFormat: '<b>{point.from}</b> → <b>{point.to}</b><br/>Applications: <b>{point.weight}</b>',
      backgroundColor: 'rgba(255, 255, 255, 0.95)',
      borderRadius: 12,
      borderWidth: 2,
      borderColor: '#E8D5B7',
      style: {
        fontSize: '13px',
        fontWeight: '500',
      },
      shadow: {
        color: 'rgba(0, 0, 0, 0.1)',
        offsetX: 0,
        offsetY: 4,
        opacity: 0.15,
        width: 8,
      },
    },
    series: [
      {
        type: 'sankey',
        name: 'Application Flow',
        keys: ['from', 'to', 'weight'],
        data: sankeyData,
        nodes: nodes.map((node) => ({
          id: node.label,
          color: node.color,
          dataLabels: {
            style: {
              fontSize: '13px',
              fontWeight: '600',
              textOutline: 'none',
              color: '#1E293B', // navy-900
            },
          },
        })),
        dataLabels: {
          enabled: true,
          style: {
            fontSize: '13px',
            fontWeight: '600',
            textOutline: 'none',
          },
        },
        linkOpacity: 0.35,
        nodeWidth: 30,
        nodePadding: 20,
        animation: {
          duration: 800,
        },
      },
    ],
    credits: {
      enabled: false,
    },
    plotOptions: {
      sankey: {
        linkOpacity: 0.35,
        states: {
          hover: {
            linkOpacity: 0.6,
          },
        },
      },
    },
  };

  return (
    <div className="w-full">
      <HighchartsReact
        highcharts={Highcharts}
        options={options}
        ref={chartRef}
      />
    </div>
  );
}
