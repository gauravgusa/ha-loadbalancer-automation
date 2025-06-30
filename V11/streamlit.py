streamlit>=1.35.0
google-generativeai>=0.5.0

import streamlit as st
import google.generativeai as genai

# Streamlit UI setup
st.title("TOC Reformation with Gemini")
st.subheader("Upload your table of contents for restructuring")

# API key input
api_key = st.text_input("Enter Gemini API Key", type="password")
genai.configure(api_key=api_key) if api_key else None

# TOC input
toc_input = st.text_area("Input Table of Contents:", height=200)

if st.button("Reform TOC") and api_key and toc_input:
    try:
        # Configure structured output schema
        response_schema = {
            "type": "object",
            "properties": {
                "reformed_toc": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "section_title": {"type": "string"},
                            "page_number": {"type": "integer"},
                            "subsections": {
                                "type": "array",
                                "items": {"type": "string"}
                            }
                        }
                    }
                }
            },
            "propertyOrdering": ["reformed_toc"]
        }

        # Initialize model with structured output config
        model = genai.GenerativeModel('gemini-1.5-flash')
        response = model.generate_content(
            f"Reformat and standardize this table of contents: {toc_input}",
            generation_config=genai.types.GenerationConfig(
                response_mime_type="application/json",
                response_schema=response_schema
            )
        )

        # Display results
        st.subheader("Reformed TOC Structure")
        reformed_data = response.text  # Contains JSON output
        st.json(reformed_data)
        
        # Display formatted output
        st.subheader("Human-Readable Format")
        if isinstance(reformed_data, dict) and 'reformed_toc' in reformed_data:
            for entry in reformed_data['reformed_toc']:
                st.markdown(f"**{entry['section_title']}** (Page {entry['page_number']})")
                for sub in entry.get('subsections', []):
                    st.markdown(f"- {sub}")
        else:
            st.error("Unexpected response format")
            
    except Exception as e:
        st.error(f"API Error: {str(e)}")
elif not api_key:
    st.warning("Please enter your Gemini API key")
elif not toc_input:
    st.warning("Please input a table of contents")
