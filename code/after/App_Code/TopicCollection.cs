public class Topic
{
    public int id { get; set; }
    public string topic { get; set; }
    public Tutorial[] tutorials { get; set; }
}

public class Tutorial
{
    public string name { get; set; }
    public string website { get; set; }
    public string url { get; set; }
    public string type { get; set; }
}
