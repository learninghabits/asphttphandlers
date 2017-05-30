<%@ WebHandler Language="C#" Class="Handler" %>

using System;
using System.IO;
using System.Collections.Generic;
using System.Web;
using Newtonsoft.Json;
using System.Linq;
using System.Collections.Specialized;

public class Handler : IHttpHandler
{
    Dictionary<string, Action<HttpContext>> _handlers =
               new Dictionary<string, Action<HttpContext>>();

    static Topic[] _topicsCollection;

    static Handler()
    {
        string filePath = HttpContext.Current.Server.MapPath("~/topics.json");
        var topicsFileContent = File.ReadAllText(filePath);
        _topicsCollection = JsonConvert.DeserializeObject<Topic[]>(topicsFileContent);
    }

    public Handler()
    {
        _handlers.Add("GET('/')", Get);
        _handlers.Add("GET('/api/topics')", GetTopics);
        _handlers.Add("GET('/api/topic/:id')", GetTopic);
        _handlers.Add("GET('/api/topic/:id/:name')", GetTutorial);
        _handlers.Add("POST('/api/topic')", PostTopic);      
    }

    public void ProcessRequest(HttpContext context)
    {
        var key = GetKey(context.Request);

        if (_handlers.ContainsKey(key))
        {
            var handler = _handlers[key];
            handler(context);
        }
        else
        {
            context.Response.ContentType = "text/plain";
            context.Response.StatusCode = 200;
            var response = "No suitable handler found for your request";
            context.Response.Write(response);
        }
    }

    string GetKey(HttpRequest request)
    {
        string key = "";
        var incomingKeyParts = (string.Format("{0}('{1}')",
                request.HttpMethod,
                request.PathInfo)).Split('/');
        _handlers.Keys.ToList().ForEach(k =>
        {
            var registeredHandlerKeyParts = k.Split('/');
            if (registeredHandlerKeyParts.Length != incomingKeyParts.Length)
            {
                return;
            }
            NameValueCollection _keyValPairs = new NameValueCollection();
            for (int i = 0; i < registeredHandlerKeyParts.Length; i++)
            {
                if (registeredHandlerKeyParts[i].StartsWith(":"))
                {
                    _keyValPairs.Add(CleanKey(registeredHandlerKeyParts[i]),
                                     CleanKey(incomingKeyParts[i]));
                }
                else if (registeredHandlerKeyParts[i] != incomingKeyParts[i])
                {
                    return;
                }
            }
            request.Headers.Add(_keyValPairs);
            key = k;
        });
        return key;
    }

    string CleanKey(string val)
    {
        return val.Replace(":", "")
                  .Replace("'", "")
                  .Replace(")", "")
                  .Replace("(", "");
    }

    void Get(HttpContext context)
    {
        context.Response.ContentType = "text/plain";
        context.Response.StatusCode = 200;
        var response = "API is ready to receive requests";
        context.Response.Write(response);
    }

    void GetTopics(HttpContext context)
    {
        var topics = _topicsCollection.Select(t => new
        {
            id = t.id,
            topic = t.topic
        });
        context.Response.ContentType = "application/json";
        context.Response.StatusCode = 200;
        context.Response.Write(JsonConvert.SerializeObject(topics));
    }

    void GetTopic(HttpContext context)
    {
        context.Response.ContentType = "application/json";

        int id;
        if (!int.TryParse(context.Request.Headers["id"], out id))
        {
            context.Response.StatusCode = 400;
            context.Response.Write(JsonConvert.SerializeObject(new
            {
                message = "The API expects an integer value for an id"
            }));
            return;
        }

        var topic = _topicsCollection.SingleOrDefault(t => t.id == id);
        if (topic == null)
        {
            context.Response.StatusCode = 404;
            context.Response.Write(JsonConvert.SerializeObject(new
            {
                message = "The topic you requested was not found"
            }));
        }
        else
        {
            context.Response.StatusCode = 200;
            context.Response.Write(JsonConvert.SerializeObject(topic));
        }
    }

    void GetTutorial(HttpContext context)
    {
        context.Response.ContentType = "application/json";

        int id;
        if (!int.TryParse(context.Request.Headers["id"], out id))
        {
            context.Response.StatusCode = 400;
            context.Response.Write(JsonConvert.SerializeObject(new
            {
                message = "The API expects an integer value for an id"
            }));
            return;
        }

        var name = context.Request.Headers["name"];

        if (string.IsNullOrEmpty(name))
        {
            context.Response.StatusCode = 400;
            context.Response.Write(JsonConvert.SerializeObject(new
            {
                message = "The API expects an tutorial name"
            }));
            return;
        }

        var tutorials = _topicsCollection.Where(t => t.id == id)
                                     .SelectMany(t => t.tutorials)
                                     .Where(t => t.name == name)
                                     .ToList();

        if (tutorials.Count == 0)
        {
            context.Response.StatusCode = 404;
            context.Response.Write(JsonConvert.SerializeObject(new
            {
                message = "The tutorial  you requested was not found"
            }));
        }
        else
        {
            context.Response.StatusCode = 200;
            context.Response.Write(JsonConvert.SerializeObject(new
            {
                id = id,
                tutorials = tutorials
            }));
        }
    }

    void PostTopic(HttpContext context)
    {
        context.Response.ContentType = "application/json";
        StreamReader reader = new StreamReader(context.Request.InputStream);
        string topicJsonString = reader.ReadToEnd();
        if (string.IsNullOrEmpty(topicJsonString))
        {
            context.Response.StatusCode = 404;
            context.Response.Write(JsonConvert.SerializeObject(new
            {
                message = "Bad data received for a post topic request"
            }));
        }
        else
        {
            //TODO:- what is the data is not deserializable??
            Topic topic = JsonConvert.DeserializeObject<Topic>(topicJsonString);
            topic.id = _topicsCollection.Last().id + 1;
            var topicList = _topicsCollection.ToList();
            topicList.Add(topic);
            _topicsCollection = topicList.ToArray();
            context.Response.StatusCode = 200;
            context.Response.Write(JsonConvert.SerializeObject(new
            {
                id = topic.id,
                url = context.Request.Url.AbsoluteUri.Replace(context.Request.PathInfo, "") 
                        + "/api/topic/" + topic.id
            }));

        }
    }

    public bool IsReusable
    {
        get
        {
            return false;
        }
    }
}