FROM python:3.9

WORKDIR /code

COPY ./requirements.txt /code/requirements.txt
RUN pip install --no-cache-dir --upgrade -r /code/requirements.txt

# Copy necessary files from parent context (simulated by copying local files)
# In HF Spaces, we standardly copy the current directory.
# But we need groq_client.py from the parent directory.
# We'll assume the user pushes the CONTENTS of Voice folder + groq_client.py 
# actually, simpler: I will copy groq_client.py INTO the Voice folder so it is self-contained for the Space.

COPY . /code

# Log for debugging
RUN ls -la /code

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "7860"]
