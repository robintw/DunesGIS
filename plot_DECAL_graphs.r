library(ggplot2)
library(reshape)

plot_graphs("D:\\results.csv", "Test DECAL plot")

plot_graphs <- function(filename, title) {
df = read.csv(filename, header=T)

df <- df[,-match("z_score",names(df))]
df <- df[,-match("p_value",names(df))]
df <- df[,-match("min_len",names(df))]

names(df)

m <- melt(df, id = c('name', 't'))


m$titles <- ordered(m$variable,
		levels = c('n', 'mean_len', 'max_len', 'total_len', 'stdev_len', 'mean_closeness', 'std_closeness', 'defect_dens', 'r_score'),
		labels = c('No of dunes', 'Mean Length', 'Max Length', 'Total Length', 'StDev Length', 'Mean Closeness', "StDev Closeness", "Defect Density", "R-score"))

g <- ggplot(m, aes(x = t, y = value))
g + geom_point() + geom_line() +
     facet_wrap( ~ titles, ncol = 3, scales = 'free_y') +
	theme_bw() + ylab("") + xlab("Time") + opts(strip.background=theme_blank()) +
	scale_x_continuous(breaks=0:4, labels="") +
	opts(axis.title.x = theme_text(size = 10, vjust = 2.5, hjust = 0.5)) + 
	opts(title = title)
}