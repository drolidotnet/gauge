import pandas as pd
import plotly.graph_objects as go
from datetime import datetime

def create_visualization(csv_path="fng_log.csv"):
    # Read the CSV file with explicit column names
    df = pd.read_csv(csv_path, names=['date', 'score', 'rating'])
    
    # Convert date to datetime
    df['date'] = pd.to_datetime(df['date'])
    
    # Create the figure
    fig = go.Figure()
    
    # Add the line trace
    fig.add_trace(go.Scatter(
        x=df['date'],
        y=df['score'],
        mode='lines+markers',
        marker=dict(
            size=6,
            color='#007AFF',  # Apple-like blue
        ),
        line=dict(
            color='#007AFF',
            width=2
        ),
        hovertemplate=(
            "<b>Date:</b> %{x|%Y-%m-%d}<br>" +
            "<b>Score:</b> %{y}<br>" +
            "<b>Rating:</b> %{customdata}<br>" +
            "<extra></extra>"  # Removes the secondary box
        ),
        customdata=df['rating']
    ))
    
    # Update layout for a modern look
    fig.update_layout(
        title=dict(
            text='Fear & Greed Index Over Time',
            x=0.5,
            y=0.95,
            xanchor='center',
            yanchor='top',
            font=dict(size=24)
        ),
        xaxis=dict(
            title='Date',
            showgrid=True,
            gridcolor='#E5E5EA',
            zeroline=False,
            rangeslider=dict(visible=True),  # Adds a range slider at the bottom
            type='date'
        ),
        yaxis=dict(
            title='Score',
            showgrid=True,
            gridcolor='#E5E5EA',
            zeroline=False,
            range=[0, 100]
        ),
        plot_bgcolor='white',
        hovermode='x unified',  # Shows all points at the current x position
        showlegend=False,
        margin=dict(t=50, l=50, r=50, b=50),
        height=600,  # Taller for better visibility
    )
    
    # Add range selector buttons
    fig.update_layout(
        xaxis=dict(
            rangeselector=dict(
                buttons=list([
                    dict(count=1, label="1m", step="month", stepmode="backward"),
                    dict(count=3, label="3m", step="month", stepmode="backward"),
                    dict(count=6, label="6m", step="month", stepmode="backward"),
                    dict(count=1, label="1y", step="year", stepmode="backward"),
                    dict(step="all", label="All")
                ])
            )
        )
    )
    
    # Show the plot
    fig.show()

if __name__ == "__main__":
    create_visualization() 