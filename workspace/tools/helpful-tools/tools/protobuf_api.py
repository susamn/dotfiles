from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import base64
import subprocess
import tempfile
import os
import json
import re
from google.protobuf.json_format import MessageToJson, Parse
from google.protobuf.message import Message
from google.protobuf.descriptor_pb2 import FileDescriptorSet
from google.protobuf.descriptor_pool import DescriptorPool
from google.protobuf import message_factory

router = APIRouter()

class ProtobufDecodeRequest(BaseModel):
    proto_schema: str
    encoded_message: str
    message_type: str

class ProtobufDecodeResponse(BaseModel):
    decoded_message: dict
    success: bool
    error: str = None

class ProtobufEncodeRequest(BaseModel):
    proto_schema: str
    json_data: str
    message_type: str

class ProtobufEncodeResponse(BaseModel):
    encoded_message: str
    success: bool
    error: str = None

def validate_proto_schema(proto_content: str) -> list:
    """Validate proto schema and return list of available message types"""
    if not proto_content.strip():
        raise ValueError("Proto schema cannot be empty")
    
    if 'syntax = "proto3"' not in proto_content and 'syntax = "proto2"' not in proto_content:
        raise ValueError("Proto schema must specify syntax (proto2 or proto3)")
    
    # Extract package name if it exists
    package_match = re.search(r'package\s+([a-zA-Z_][a-zA-Z0-9_.]*)\s*;', proto_content)
    package_name = package_match.group(1) if package_match else None
    
    # Find all message types
    message_types = re.findall(r'message\s+(\w+)\s*\{', proto_content)
    if not message_types:
        raise ValueError("No message types found in proto schema")
    
    # Add package prefix if package is declared
    if package_name:
        message_types = [f"{package_name}.{msg_type}" for msg_type in message_types]
    
    return message_types

def compile_proto_and_get_message_class(proto_content: str, message_type: str):
    with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.proto') as proto_file:
        proto_file.write(proto_content)
        proto_filename = proto_file.name

    try:
        with tempfile.TemporaryDirectory() as temp_dir:
            descriptor_filename = os.path.join(temp_dir, "descriptor.pb")

            process = subprocess.run(
                [
                    'protoc',
                    f'--proto_path={os.path.dirname(proto_filename)}',
                    f'--descriptor_set_out={descriptor_filename}',
                    os.path.basename(proto_filename)
                ],
                capture_output=True,
                text=True,
                check=True
            )

            with open(descriptor_filename, 'rb') as f:
                descriptor_set = FileDescriptorSet.FromString(f.read())
            
            # Create a new descriptor pool and add the file descriptors
            pool = DescriptorPool()
            for file_descriptor_proto in descriptor_set.file:
                pool.Add(file_descriptor_proto)
            
            # Find the message descriptor and create the message class
            message_descriptor = pool.FindMessageTypeByName(message_type)
            
            # Use the correct method for protobuf 6.x
            message_class = message_factory.GetMessageClass(message_descriptor)
            return message_class

    except subprocess.CalledProcessError as e:
        error_msg = e.stderr if e.stderr else "Unknown protoc error"
        raise RuntimeError(f"Protocol buffer compilation failed: {error_msg}")
    except Exception as e:
        raise RuntimeError(f"Failed to compile proto or find message type '{message_type}': {str(e)}")
    finally:
        if os.path.exists(proto_filename):
            os.unlink(proto_filename)

@router.post("/decode", response_model=ProtobufDecodeResponse)
async def decode_protobuf(request: ProtobufDecodeRequest):
    try:
        # Validate proto schema first
        available_types = validate_proto_schema(request.proto_schema)
        if request.message_type not in available_types:
            return ProtobufDecodeResponse(
                decoded_message={}, 
                success=False, 
                error=f"Message type '{request.message_type}' not found. Available types: {', '.join(available_types)}"
            )
        
        message_class = compile_proto_and_get_message_class(request.proto_schema, request.message_type)
        
        try:
            message_bytes = base64.b64decode(request.encoded_message)
        except Exception as e:
            return ProtobufDecodeResponse(decoded_message={}, success=False, error=f"Invalid Base64 input: {str(e)}")

        message = message_class()
        try:
            message.ParseFromString(message_bytes)
        except Exception as e:
            return ProtobufDecodeResponse(decoded_message={}, success=False, error=f"Failed to parse protobuf message: {str(e)}")
        
        json_output = MessageToJson(message, preserving_proto_field_name=True)
        return ProtobufDecodeResponse(decoded_message=json.loads(json_output), success=True)

    except Exception as e:
        return ProtobufDecodeResponse(decoded_message={}, success=False, error=str(e))

@router.post("/encode", response_model=ProtobufEncodeResponse)
async def encode_protobuf(request: ProtobufEncodeRequest):
    try:
        # Validate proto schema first
        available_types = validate_proto_schema(request.proto_schema)
        if request.message_type not in available_types:
            return ProtobufEncodeResponse(
                encoded_message="", 
                success=False, 
                error=f"Message type '{request.message_type}' not found. Available types: {', '.join(available_types)}"
            )
        
        message_class = compile_proto_and_get_message_class(request.proto_schema, request.message_type)
        
        # Parse and validate JSON data
        try:
            json_data = json.loads(request.json_data)
        except json.JSONDecodeError as e:
            return ProtobufEncodeResponse(encoded_message="", success=False, error=f"Invalid JSON data: {str(e)}")
        
        # Create message instance and populate from JSON
        message = message_class()
        try:
            Parse(request.json_data, message)
        except Exception as e:
            return ProtobufEncodeResponse(encoded_message="", success=False, error=f"Failed to parse JSON into protobuf message: {str(e)}")
        
        # Serialize to binary and encode as base64
        try:
            binary_data = message.SerializeToString()
            encoded_message = base64.b64encode(binary_data).decode('utf-8')
            return ProtobufEncodeResponse(encoded_message=encoded_message, success=True)
        except Exception as e:
            return ProtobufEncodeResponse(encoded_message="", success=False, error=f"Failed to serialize message: {str(e)}")

    except Exception as e:
        return ProtobufEncodeResponse(encoded_message="", success=False, error=str(e))
