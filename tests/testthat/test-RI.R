context("R interface")

test_that("multiple datasets works",{
    #make a list of count matrices
    nmats <- 4; nc <- 500; nr <- 5
    clist <- lapply(1:nmats, function(r) matrix(rpois(nr*nc, lambda=500), nrow=nr))
    marks <- paste0("mark", 1:nr)
    for (i in seq_along(clist)) rownames(clist[[i]]) <- marks
    dsetNames <- paste0("dataset",1:nmats)
    names(clist) <- dsetNames

    #normalize counts
    clist <- normalizecounts(clist)
    for (method in c("TMM", "RLE")){
        normalizecounts(clist, epicseg:::linearNormalization, method=method)
    }
    
    #make some matching regions
    binsize <- 200
    gr <- GRanges(seqnames="chr1", IRanges(start=1, width=binsize*nc))

    #segment
    s <- suppressMessages(segment(clist, gr, 5, verbose=F))
    
    expect_equal(names(s$segments), dsetNames)
    expect_equal(dimnames(s$posteriors)[[3]], dsetNames)
    expect_equal(dimnames(s$states)[[2]], dsetNames)
    expect_equal(dimnames(s$viterbi)[[2]], dsetNames)
    expect_equal(s$model$marks, marks)
    
    report(s$segments, s$model, outdir=tempdir(), prefix="test")}
    
)


test_that("kfoots error handler", {
    # test getBin function
    gr = GRanges(seqnames=c(1,    1,    2,   3), 
            IRanges(start=c(200,  800,  400, 600),
                    end  =c(1000, 1000, 800, 800)-1))
    binsize <- 200
    expect_equal(sum(width(gr)) %% binsize, 0)
    bins <- unlist(tile(gr, width=binsize))
    nbins <- length(bins)
    mybins <- do.call(c, sapply(1:nbins, getBin, regions=gr, binsize=binsize))
    mybins2 <- do.call(c, sapply(nbins + (1:nbins), getBin, regions=gr, binsize=binsize))
    
    f <- function(gr) paste0(seqnames(gr), start(gr), end(gr), sep="@")
    expect_equal(f(mybins), f(bins))
    expect_equal(f(mybins2), f(bins))
    
    
    # make sure an underflow returns an exception with the word 'underflow'
    uflow <- get(load(system.file("extdata/uflow_minimal.Rdata", package="epicseg")))
    model <- list(emisP=uflow$models, transP=uflow$trans, initP=uflow$initP, 
                  marks=rownames(uflow$counts))
    counts <- uflow$counts
    regions <- GRanges(seqnames="foo", IRanges(start=200, width=400))
    expect_error(segment(counts, regions, model=model, verbose=F),
                 regexp="underflow", ignore.case=T)
    # try case of a count list
    clist <- list(dset1=counts, dset2=counts)
    model2 <- model
    nstates <- length(model$emisP)
    unif_init_p <- rep(1/nstates, nstates)
    model2$initP <- cbind(unif_init_p, model$initP)
    expect_error(segment(clist, regions, model=model2, verbose=F),
                 regexp="underflow", ignore.case=T)
})
