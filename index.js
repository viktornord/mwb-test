const { Transform } = require('stream');
const getFileSize = require('filesize');
const { S3, DynamoDB: { DocumentClient } } = require('aws-sdk');
const Busboy = require('busboy');
const { createServer, STATUS_CODES } = require('http');

const s3 = new S3();
const dynamoDb = new DocumentClient({
  region: 'eu-west-1'
});

const FILE_UPLOAD_PATH = '/mwb-test/file';
const BUCKET_NAME = 'mwb--test';
const TABLE_NAME = 'mwb-test';

createServer(async function (req, res) {
  if (req.url === FILE_UPLOAD_PATH && req.method === 'POST') {
    const handlePromises = [];
    const busboy = new Busboy({ headers: req.headers });
    req.pipe(busboy);
    busboy.on('file', (fieldname, file, filename) => {
      handlePromises.push(onFileUpload({ filename, file }));
    });
    busboy.on('finish', async () => {
      await Promise.all(handlePromises);
      res.end();
    });
  } else {
    res.statusCode = 404;
    res.statusMessage = STATUS_CODES[res.statusCode];
    res.end();
  }
}).listen(3000);


async function onFileUpload({ filename, file }) {
  if (!await checkIfFileExists({ filename })) {
    console.log(`Uploading ${filename}`);
    let bytes = 0;
    await s3.upload({
      Bucket: BUCKET_NAME,
      Key: filename,
      Body: file.pipe(new Transform({
        transform(chunk, encoding, callback) {
          this.push(chunk, encoding);
          bytes += chunk.toString().length;
          callback();
        }
      })),
    }).promise();
    const fileSize = getFileSize(bytes);
    await saveUploadEvent({ filename, fileSize });
    console.log(`Saved ${filename} ${fileSize}`);
  } else {
    await saveReceiveEvent({ filename });
    file.resume();
    console.log(`${filename} already exists`);
  }
}

async function checkIfFileExists({ filename }) {
  try {
    await s3.headObject({
      Bucket: BUCKET_NAME,
      Key: filename
    }).promise();
    return true;
  } catch (error) {
    return false;
  }
}

function saveUploadEvent({ filename, fileSize }) {
  return dynamoDb.put({
    TableName: TABLE_NAME,
    Item: {
      insert_timestamp: new Date().getTime(),
      filename,
      file_size: fileSize,
      receive_events: [{ time: new Date().getTime() }]
    }
  }).promise();
}

function saveReceiveEvent({ filename }) {
  return dynamoDb.update({
    TableName: TABLE_NAME,
    Key: {
      filename,
    },
    UpdateExpression: "set receive_events = list_append (receive_events, :receiveEvent)",
    ExpressionAttributeValues: {
      ':receiveEvent': [{ time: new Date().getTime() }],
    },
  }).promise();
}
